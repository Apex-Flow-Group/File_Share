#include "my_application.h"

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  gtk_window_set_default_icon_name("apexsender");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
