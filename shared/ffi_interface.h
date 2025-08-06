#pragma once

#include "export.h"

#ifdef __cplusplus
extern "C" {
#endif

// News Service
MD_API const char* get_news_data();
MD_API int add_news_feed(const char* url);
MD_API int remove_news_feed(const char* url);

// Stream Service
MD_API int start_stream(const char* url);
MD_API int stop_stream(const char* stream_id);
MD_API const char* get_stream_data(const char* stream_id);

// Weather Service
MD_API const char* get_weather_data();
MD_API int update_weather_location(const char* location);

// Todo Service
MD_API const char* get_todo_data();
MD_API int add_todo_item(const char* json_data);
MD_API int update_todo_item(const char* json_data);
MD_API int delete_todo_item(const char* item_id);

// Mail Service
MD_API const char* get_mail_data();
MD_API int configure_mail_account(const char* json_config);

// Core Engine
MD_API int initialize_dashboard_engine();
MD_API int shutdown_dashboard_engine();
MD_API int update_widget_config(const char* widget_id, const char* config_json);

#ifdef __cplusplus
}
#endif