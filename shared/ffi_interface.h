#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// News Service
const char* get_news_data();
int add_news_feed(const char* url);
int remove_news_feed(const char* url);

// Stream Service  
int start_stream(const char* url);
int stop_stream(const char* stream_id);
const char* get_stream_data(const char* stream_id);

// Weather Service
const char* get_weather_data();
int update_weather_location(const char* location);

// Todo Service
const char* get_todo_data();
int add_todo_item(const char* json_data);
int update_todo_item(const char* json_data);
int delete_todo_item(const char* item_id);

// Mail Service
const char* get_mail_data();
int configure_mail_account(const char* json_config);

// Core Engine
int initialize_dashboard_engine();
int shutdown_dashboard_engine();
int update_widget_config(const char* widget_id, const char* config_json);

#ifdef __cplusplus
}
#endif