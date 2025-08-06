#ifndef FFI_INTERFACE_H
#define FFI_INTERFACE_H

#ifdef __cplusplus
extern "C" {
#endif

// Core engine functions
int initialize_dashboard_engine();
int shutdown_dashboard_engine();
int update_widget_config(const char* widgetId, const char* configJson);

// News functions
char* get_news_data();
int add_news_feed(const char* url);
int remove_news_feed(const char* url);

// Weather functions  
char* get_weather_data();
int update_weather_location(const char* location);

// Todo functions
char* get_todo_data();
int add_todo_item(const char* jsonData);
int update_todo_item(const char* jsonData);
int delete_todo_item(const char* itemId);

// Mail functions
char* get_mail_data();
int configure_mail_account(const char* jsonConfig);

// Stream functions
int start_stream(const char* url);
int stop_stream(const char* streamId);
char* get_stream_data(const char* streamId);

#ifdef __cplusplus
}
#endif

#endif // FFI_INTERFACE_H