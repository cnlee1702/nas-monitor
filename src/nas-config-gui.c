/*
 * NAS Monitor Configuration GUI
 * Lightweight GTK3-based configuration editor
 * 
 * Compile with:
 * gcc -o nas-config-gui nas-config-gui.c `pkg-config --cflags --libs gtk+-3.0` -std=c99
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#define MAX_PATH 512
#define MAX_LINE 1024
#define MAX_NETWORKS 10
#define MAX_NAS_DEVICES 10

typedef struct {
    char config_path[MAX_PATH];
    char home_networks[MAX_LINE];
    char nas_devices[MAX_NAS_DEVICES][MAX_LINE];
    int nas_count;
    int home_ac_interval;
    int home_battery_interval;
    int away_ac_interval;
    int away_battery_interval;
    int max_failed_attempts;
    int min_battery_level;
    gboolean enable_notifications;
} Config;

typedef struct {
    GtkWidget *window;
    GtkWidget *networks_entry;
    GtkWidget *nas_listbox;
    GtkWidget *home_ac_spin;
    GtkWidget *home_battery_spin;
    GtkWidget *away_ac_spin;
    GtkWidget *away_battery_spin;
    GtkWidget *max_attempts_spin;
    GtkWidget *min_battery_spin;
    GtkWidget *notifications_check;
    GtkWidget *status_label;
    Config config;
} AppData;

static void show_error(GtkWidget *parent, const char *message) {
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(parent),
        GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_ERROR,
        GTK_BUTTONS_OK,
        "%s", message
    );
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

static void show_info(GtkWidget *parent, const char *message) {
    GtkWidget *dialog = gtk_message_dialog_new(
        GTK_WINDOW(parent),
        GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_INFO,
        GTK_BUTTONS_OK,
        "%s", message
    );
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

static void init_config_path(AppData *app) {
    const char *home = getenv("HOME");
    if (!home) {
        strcpy(app->config.config_path, "/tmp/nas-monitor-config.conf");
        return;
    }
    
    snprintf(app->config.config_path, MAX_PATH, 
             "%s/.config/nas-monitor/config.conf", home);
    
    // Create directory if it doesn't exist
    char dir_path[MAX_PATH];
    snprintf(dir_path, MAX_PATH, "%s/.config/nas-monitor", home);
    mkdir(dir_path, 0700);
}

static void set_defaults(Config *config) {
    strcpy(config->home_networks, "");
    config->nas_count = 0;
    config->home_ac_interval = 15;
    config->home_battery_interval = 60;
    config->away_ac_interval = 180;
    config->away_battery_interval = 600;
    config->max_failed_attempts = 3;
    config->min_battery_level = 10;
    config->enable_notifications = TRUE;
}

static gboolean load_config(AppData *app) {
    FILE *file = fopen(app->config.config_path, "r");
    if (!file) {
        set_defaults(&app->config);
        return FALSE;
    }
    
    char line[MAX_LINE];
    char section[64] = "";
    
    set_defaults(&app->config);
    
    while (fgets(line, sizeof(line), file)) {
        // Remove trailing newline
        char *newline = strchr(line, '\n');
        if (newline) *newline = '\0';
        
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\0' || strspn(line, " \t") == strlen(line)) {
            continue;
        }
        
        // Check for section headers
        if (line[0] == '[' && line[strlen(line)-1] == ']') {
            strncpy(section, line + 1, sizeof(section) - 1);
            section[strlen(section) - 1] = '\0';
            continue;
        }
        
        // Parse key-value pairs
        char *equals = strchr(line, '=');
        if (equals) {
            *equals = '\0';
            char *key = line;
            char *value = equals + 1;
            
            // Trim whitespace
            while (*key == ' ' || *key == '\t') key++;
            while (*value == ' ' || *value == '\t') value++;
            
            if (strcmp(key, "home_networks") == 0) {
                strncpy(app->config.home_networks, value, MAX_LINE - 1);
            } else if (strcmp(key, "home_ac_interval") == 0) {
                app->config.home_ac_interval = atoi(value);
            } else if (strcmp(key, "home_battery_interval") == 0) {
                app->config.home_battery_interval = atoi(value);
            } else if (strcmp(key, "away_ac_interval") == 0) {
                app->config.away_ac_interval = atoi(value);
            } else if (strcmp(key, "away_battery_interval") == 0) {
                app->config.away_battery_interval = atoi(value);
            } else if (strcmp(key, "max_failed_attempts") == 0) {
                app->config.max_failed_attempts = atoi(value);
            } else if (strcmp(key, "min_battery_level") == 0) {
                app->config.min_battery_level = atoi(value);
            } else if (strcmp(key, "enable_notifications") == 0) {
                app->config.enable_notifications = (strcmp(value, "true") == 0);
            }
        } else if (strcmp(section, "nas_devices") == 0 && 
                   strstr(line, "/") && app->config.nas_count < MAX_NAS_DEVICES) {
            // NAS device entry
            strncpy(app->config.nas_devices[app->config.nas_count], line, MAX_LINE - 1);
            app->config.nas_count++;
        }
    }
    
    fclose(file);
    return TRUE;
}

static gboolean save_config(AppData *app) {
    FILE *file = fopen(app->config.config_path, "w");
    if (!file) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), 
                "Failed to save configuration: %s", strerror(errno));
        show_error(app->window, error_msg);
        return FALSE;
    }
    
    // Set restrictive permissions
    chmod(app->config.config_path, 0600);
    
    fprintf(file, "# NAS Monitor Configuration File\n\n");
    
    fprintf(file, "[networks]\n");
    fprintf(file, "# Comma-separated list of home network SSIDs\n");
    fprintf(file, "home_networks=%s\n\n", app->config.home_networks);
    
    fprintf(file, "[nas_devices]\n");
    fprintf(file, "# Format: host/share (one per line)\n");
    for (int i = 0; i < app->config.nas_count; i++) {
        fprintf(file, "%s\n", app->config.nas_devices[i]);
    }
    
    fprintf(file, "\n[intervals]\n");
    fprintf(file, "# Check intervals in seconds\n");
    fprintf(file, "home_ac_interval=%d\n", app->config.home_ac_interval);
    fprintf(file, "home_battery_interval=%d\n", app->config.home_battery_interval);
    fprintf(file, "away_ac_interval=%d\n", app->config.away_ac_interval);
    fprintf(file, "away_battery_interval=%d\n", app->config.away_battery_interval);
    
    fprintf(file, "\n[behavior]\n");
    fprintf(file, "max_failed_attempts=%d\n", app->config.max_failed_attempts);
    fprintf(file, "min_battery_level=%d\n", app->config.min_battery_level);
    fprintf(file, "enable_notifications=%s\n", 
            app->config.enable_notifications ? "true" : "false");
    
    fclose(file);
    
    gtk_label_set_text(GTK_LABEL(app->status_label), 
                       "Configuration saved successfully");
    
    return TRUE;
}

static void update_ui_from_config(AppData *app) {
    gtk_entry_set_text(GTK_ENTRY(app->networks_entry), app->config.home_networks);
    
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->home_ac_spin), 
                              app->config.home_ac_interval);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->home_battery_spin), 
                              app->config.home_battery_interval);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->away_ac_spin), 
                              app->config.away_ac_interval);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->away_battery_spin), 
                              app->config.away_battery_interval);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->max_attempts_spin), 
                              app->config.max_failed_attempts);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(app->min_battery_spin), 
                              app->config.min_battery_level);
    
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(app->notifications_check),
                                 app->config.enable_notifications);
    
    // Clear and repopulate NAS list
    GList *children = gtk_container_get_children(GTK_CONTAINER(app->nas_listbox));
    for (GList *iter = children; iter != NULL; iter = g_list_next(iter)) {
        gtk_widget_destroy(GTK_WIDGET(iter->data));
    }
    g_list_free(children);
    
    for (int i = 0; i < app->config.nas_count; i++) {
        GtkWidget *row = gtk_list_box_row_new();
        GtkWidget *label = gtk_label_new(app->config.nas_devices[i]);
        gtk_label_set_xalign(GTK_LABEL(label), 0.0);
        gtk_container_add(GTK_CONTAINER(row), label);
        gtk_list_box_insert(GTK_LIST_BOX(app->nas_listbox), row, -1);
    }
    
    gtk_widget_show_all(app->nas_listbox);
}

static void update_config_from_ui(AppData *app) {
    strncpy(app->config.home_networks, 
            gtk_entry_get_text(GTK_ENTRY(app->networks_entry)), MAX_LINE - 1);
    
    app->config.home_ac_interval = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->home_ac_spin));
    app->config.home_battery_interval = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->home_battery_spin));
    app->config.away_ac_interval = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->away_ac_spin));
    app->config.away_battery_interval = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->away_battery_spin));
    app->config.max_failed_attempts = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->max_attempts_spin));
    app->config.min_battery_level = gtk_spin_button_get_value_as_int(
        GTK_SPIN_BUTTON(app->min_battery_spin));
    
    app->config.enable_notifications = gtk_toggle_button_get_active(
        GTK_TOGGLE_BUTTON(app->notifications_check));
}

static void on_add_nas_clicked(GtkButton *button __attribute__((unused)), AppData *app) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "Add NAS Device",
        GTK_WINDOW(app->window),
        GTK_DIALOG_MODAL,
        "Cancel", GTK_RESPONSE_CANCEL,
        "Add", GTK_RESPONSE_OK,
        NULL
    );
    
    GtkWidget *content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "hostname.local/share");
    
    gtk_container_add(GTK_CONTAINER(content), 
                      gtk_label_new("Enter NAS device (format: host/share):"));
    gtk_container_add(GTK_CONTAINER(content), entry);
    gtk_widget_show_all(content);
    
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_OK) {
        const char *text = gtk_entry_get_text(GTK_ENTRY(entry));
        if (strlen(text) > 0 && strstr(text, "/") && 
            app->config.nas_count < MAX_NAS_DEVICES) {
            strncpy(app->config.nas_devices[app->config.nas_count], text, MAX_LINE - 1);
            app->config.nas_count++;
            update_ui_from_config(app);
        }
    }
    
    gtk_widget_destroy(dialog);
}

static void on_remove_nas_clicked(GtkButton *button __attribute__((unused)), AppData *app) {
    GtkListBoxRow *selected = gtk_list_box_get_selected_row(GTK_LIST_BOX(app->nas_listbox));
    if (!selected) {
        show_info(app->window, "Please select a NAS device to remove.");
        return;
    }
    
    int index = gtk_list_box_row_get_index(selected);
    
    // Remove from config array
    for (int i = index; i < app->config.nas_count - 1; i++) {
        strcpy(app->config.nas_devices[i], app->config.nas_devices[i + 1]);
    }
    app->config.nas_count--;
    
    update_ui_from_config(app);
}

static void on_save_clicked(GtkButton *button __attribute__((unused)), AppData *app) {
    update_config_from_ui(app);
    save_config(app);
}

static void on_restart_service_clicked(GtkButton *button __attribute__((unused)), AppData *app) {
    int result = system("systemctl --user restart nas-monitor.service 2>/dev/null");
    if (result == 0) {
        gtk_label_set_text(GTK_LABEL(app->status_label), 
                           "Service restarted successfully");
    } else {
        gtk_label_set_text(GTK_LABEL(app->status_label), 
                           "Failed to restart service");
    }
}

static void create_ui(AppData *app) {
    app->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app->window), "NAS Monitor Configuration");
    gtk_window_set_default_size(GTK_WINDOW(app->window), 500, 600);
    gtk_window_set_position(GTK_WINDOW(app->window), GTK_WIN_POS_CENTER);
    
    // Create main container that will hold everything
    GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    
    // Create notebook for tabs
    GtkWidget *notebook = gtk_notebook_new();
    
    // Networks tab
    GtkWidget *networks_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(networks_box), 10);
    
    gtk_box_pack_start(GTK_BOX(networks_box), 
                       gtk_label_new("Home Networks (comma-separated):"), FALSE, FALSE, 0);
    app->networks_entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(app->networks_entry), "WiFi-Name1,WiFi-Name2");
    gtk_box_pack_start(GTK_BOX(networks_box), app->networks_entry, FALSE, FALSE, 0);
    
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), networks_box, 
                             gtk_label_new("Networks"));
    
    // NAS Devices tab
    GtkWidget *nas_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(nas_box), 10);
    
    gtk_box_pack_start(GTK_BOX(nas_box), 
                       gtk_label_new("NAS Devices:"), FALSE, FALSE, 0);
    
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled),
                                   GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_size_request(scrolled, -1, 200);
    
    app->nas_listbox = gtk_list_box_new();
    gtk_container_add(GTK_CONTAINER(scrolled), app->nas_listbox);
    gtk_box_pack_start(GTK_BOX(nas_box), scrolled, TRUE, TRUE, 0);
    
    GtkWidget *nas_buttons = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    GtkWidget *add_button = gtk_button_new_with_label("Add");
    GtkWidget *remove_button = gtk_button_new_with_label("Remove");
    gtk_box_pack_start(GTK_BOX(nas_buttons), add_button, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(nas_buttons), remove_button, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(nas_box), nas_buttons, FALSE, FALSE, 0);
    
    g_signal_connect(add_button, "clicked", G_CALLBACK(on_add_nas_clicked), app);
    g_signal_connect(remove_button, "clicked", G_CALLBACK(on_remove_nas_clicked), app);
    
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), nas_box, 
                             gtk_label_new("NAS Devices"));
    
    // Settings tab
    GtkWidget *settings_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(settings_box), 10);
    
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 5);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 10);
    
    int row = 0;
    
    // Interval settings
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Home AC Interval (sec):"), 0, row, 1, 1);
    app->home_ac_spin = gtk_spin_button_new_with_range(5, 3600, 5);
    gtk_grid_attach(GTK_GRID(grid), app->home_ac_spin, 1, row++, 1, 1);
    
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Home Battery Interval (sec):"), 0, row, 1, 1);
    app->home_battery_spin = gtk_spin_button_new_with_range(10, 3600, 10);
    gtk_grid_attach(GTK_GRID(grid), app->home_battery_spin, 1, row++, 1, 1);
    
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Away AC Interval (sec):"), 0, row, 1, 1);
    app->away_ac_spin = gtk_spin_button_new_with_range(30, 3600, 30);
    gtk_grid_attach(GTK_GRID(grid), app->away_ac_spin, 1, row++, 1, 1);
    
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Away Battery Interval (sec):"), 0, row, 1, 1);
    app->away_battery_spin = gtk_spin_button_new_with_range(60, 3600, 60);
    gtk_grid_attach(GTK_GRID(grid), app->away_battery_spin, 1, row++, 1, 1);
    
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Max Failed Attempts:"), 0, row, 1, 1);
    app->max_attempts_spin = gtk_spin_button_new_with_range(1, 10, 1);
    gtk_grid_attach(GTK_GRID(grid), app->max_attempts_spin, 1, row++, 1, 1);
    
    gtk_grid_attach(GTK_GRID(grid), gtk_label_new("Min Battery Level (%):"), 0, row, 1, 1);
    app->min_battery_spin = gtk_spin_button_new_with_range(5, 50, 5);
    gtk_grid_attach(GTK_GRID(grid), app->min_battery_spin, 1, row++, 1, 1);
    
    app->notifications_check = gtk_check_button_new_with_label("Enable Notifications");
    gtk_grid_attach(GTK_GRID(grid), app->notifications_check, 0, row++, 2, 1);
    
    gtk_box_pack_start(GTK_BOX(settings_box), grid, FALSE, FALSE, 0);
    
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), settings_box, 
                             gtk_label_new("Settings"));
    
    // Add notebook to main container
    gtk_box_pack_start(GTK_BOX(main_box), notebook, TRUE, TRUE, 0);
    
    // Control buttons
    GtkWidget *button_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_container_set_border_width(GTK_CONTAINER(button_box), 10);
    
    GtkWidget *save_button = gtk_button_new_with_label("Save Configuration");
    GtkWidget *restart_button = gtk_button_new_with_label("Restart Service");
    
    gtk_box_pack_start(GTK_BOX(button_box), save_button, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(button_box), restart_button, TRUE, TRUE, 0);
    
    g_signal_connect(save_button, "clicked", G_CALLBACK(on_save_clicked), app);
    g_signal_connect(restart_button, "clicked", G_CALLBACK(on_restart_service_clicked), app);
    
    // Status label
    app->status_label = gtk_label_new("");
    
    // Add button box and status to main container
    gtk_box_pack_start(GTK_BOX(main_box), button_box, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(main_box), app->status_label, FALSE, FALSE, 5);
    
    // Add main container to window (this is the only child of the window)
    gtk_container_add(GTK_CONTAINER(app->window), main_box);
    
    g_signal_connect(app->window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    
    AppData app = {0};
    
    init_config_path(&app);
    load_config(&app);
    create_ui(&app);
    update_ui_from_config(&app);
    
    gtk_widget_show_all(app.window);
    gtk_main();
    
    return 0;
}