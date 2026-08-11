#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <fstream>
#include <sstream>
#include <string>
#include <ctime>

#include "flutter/generated_plugin_registrant.h"

// ─── Clipboard channel name (must match Dart side) ────────────────────────────
static const char kClipboardChannel[] = "com.apex.core/clipboard";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;

  // Clipboard monitoring
  FlMethodChannel* clipboard_channel;
  gulong            clipboard_signal_id;
  GtkClipboard*     clipboard;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// ─── Helper: temp file path ───────────────────────────────────────────────────
static std::string make_temp_path(const char* prefix, const char* ext) {
  const char* tmp = g_get_tmp_dir();
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  long tick = ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
  std::ostringstream oss;
  oss << tmp << "/" << prefix << tick << "." << ext;
  return oss.str();
}

// ─── GTK clipboard owner-change callback ─────────────────────────────────────
static void on_clipboard_changed(GtkClipboard* clipboard,
                                 GdkEvent* /*event*/,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!self->clipboard_channel) return;

  // ── Case 1: Files (text/uri-list) ────────────────────────────────────────
  GdkAtom uri_atom  = gdk_atom_intern_static_string("text/uri-list");
  GdkAtom png_atom  = gdk_atom_intern_static_string("image/png");

  if (gtk_clipboard_wait_is_target_available(clipboard, uri_atom)) {
    GtkSelectionData* sel =
        gtk_clipboard_wait_for_contents(clipboard, uri_atom);
    if (sel) {
      gchar** uris = gtk_selection_data_get_uris(sel);
      gtk_selection_data_free(sel);
      if (uris) {
        FlValue* paths_list = fl_value_new_list();
        for (int i = 0; uris[i] != nullptr; ++i) {
          gchar* path = g_filename_from_uri(uris[i], nullptr, nullptr);
          if (path) {
            fl_value_append_take(paths_list, fl_value_new_string(path));
            g_free(path);
          }
        }
        g_strfreev(uris);

        if (fl_value_get_length(paths_list) > 0) {
          g_autoptr(FlValue) args = fl_value_new_map();
          fl_value_set_string_take(args, "type", fl_value_new_string("files"));
          fl_value_set_string_take(args, "paths", paths_list);
          fl_method_channel_invoke_method(self->clipboard_channel,
                                         "onClipboardChanged", args,
                                         nullptr, nullptr, nullptr);
          return;
        }
        fl_value_unref(paths_list);
      }
    }
  }

  // ── Case 2: Image (image/png) ─────────────────────────────────────────────
  if (gtk_clipboard_wait_is_target_available(clipboard, png_atom)) {
    GtkSelectionData* sel =
        gtk_clipboard_wait_for_contents(clipboard, png_atom);
    if (sel) {
      const guchar* data = gtk_selection_data_get_data(sel);
      gint          len  = gtk_selection_data_get_length(sel);
      if (data && len > 0) {
        std::string path = make_temp_path("apex_clip_", "png");
        std::ofstream f(path, std::ios::binary);
        if (f.is_open()) {
          f.write(reinterpret_cast<const char*>(data), len);
          f.close();

          g_autoptr(FlValue) args = fl_value_new_map();
          fl_value_set_string_take(args, "type",
                                   fl_value_new_string("image"));
          g_autoptr(FlValue) paths_list = fl_value_new_list();
          fl_value_append_take(paths_list, fl_value_new_string(path.c_str()));
          fl_value_set_string(args, "paths", paths_list);
          fl_method_channel_invoke_method(self->clipboard_channel,
                                         "onClipboardChanged", args,
                                         nullptr, nullptr, nullptr);
          gtk_selection_data_free(sel);
          return;
        }
      }
      gtk_selection_data_free(sel);
    }
  }

  // ── Case 3: Plain text ────────────────────────────────────────────────────
  gchar* text = gtk_clipboard_wait_for_text(clipboard);
  if (text) {
    // Skip whitespace-only
    bool has_content = false;
    for (const char* p = text; *p; ++p) {
      if (*p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') {
        has_content = true;
        break;
      }
    }
    if (has_content) {
      std::string path = make_temp_path("apex_clip_", "txt");
      std::ofstream f(path, std::ios::binary);
      if (f.is_open()) {
        f.write(text, strlen(text));
        f.close();

        // Preview: first 100 UTF-8 characters (simple byte slice is fine for preview)
        std::string preview(text);
        bool truncated = false;
        if (preview.size() > 100) {
          preview = preview.substr(0, 100);
          truncated = true;
        }
        if (truncated) preview += "...";

        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "type", fl_value_new_string("text"));
        g_autoptr(FlValue) paths_list = fl_value_new_list();
        fl_value_append_take(paths_list, fl_value_new_string(path.c_str()));
        fl_value_set_string(args, "paths", paths_list);
        fl_value_set_string_take(args, "textPreview",
                                 fl_value_new_string(preview.c_str()));
        fl_method_channel_invoke_method(self->clipboard_channel,
                                       "onClipboardChanged", args,
                                       nullptr, nullptr, nullptr);
      }
    }
    g_free(text);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Apex File Share");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Apex File Share");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_window_set_icon_name(window, "apexsender");

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // ── Set up clipboard MethodChannel ────────────────────────────────────────
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->clipboard_channel = fl_method_channel_new(
      messenger, kClipboardChannel, FL_METHOD_CODEC(codec));

  // Dart → C++ calls not used on this channel; just return NotImplemented
  fl_method_channel_set_method_call_handler(
      self->clipboard_channel,
      [](FlMethodChannel*, FlMethodCall* call, gpointer) {
        g_autoptr(FlMethodErrorResponse) response =
            fl_method_error_response_new("NOT_IMPLEMENTED",
                                        "not implemented", nullptr);
        fl_method_call_respond(call, FL_METHOD_RESPONSE(response), nullptr);
      },
      self, nullptr);

  // ── Connect to GTK clipboard owner-change signal ──────────────────────────
  self->clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  self->clipboard_signal_id =
      g_signal_connect(self->clipboard, "owner-change",
                       G_CALLBACK(on_clipboard_changed), self);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Disconnect clipboard signal and release channel
  if (self->clipboard && self->clipboard_signal_id > 0) {
    g_signal_handler_disconnect(self->clipboard, self->clipboard_signal_id);
    self->clipboard_signal_id = 0;
    self->clipboard = nullptr;
  }
  g_clear_object(&self->clipboard_channel);

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->clipboard_channel    = nullptr;
  self->clipboard_signal_id  = 0;
  self->clipboard            = nullptr;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
