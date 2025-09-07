create or replace PACKAGE      TAPI_USER_MESSAGE AS
-- ============================================================================
-- PACKAGE            : TAPI_USER_MESSAGE
--
-- APPLICATION FUNCTION:
--     Gegevensverwerking USER_MESSAGE
--
-- PURPOSE:
--     This package can be called from VB-packages that implement an 
--     application function support a business function
--     It executes logic to perform CRUD-actions. This is done by
--     applying business rules.
--
-- CREATED BY         : Hans Blok
--
-- CHANGE LOG:
--    23-Apr-2025   HB   Initial creation
--
-- PUBLIC PROCEDURES:
--
--      md5_row
--          - 
--
--      select_table
--          - selects al row in the table by using BULK collection
--
--      select_row
--          - 
--
--      insert_row
--          - 
--
--      update_row
--          - 
--
--      delete_row
--          - 
--  PUBLIC FUNCTIONS:
--
--      get_user_message_text
--          - selects and returns the message text for a code
--
-- ============================================================================
   TYPE g_tab_user_message IS TABLE OF USER_MESSAGE%ROWTYPE;

   FUNCTION md5_row
      ( p_ref_application_domain_id     IN user_message.ref_application_domain_id%TYPE
      , p_ref_user_message_type_id      IN user_message.ref_user_message_type_id%TYPE
      , p_code                          IN user_message.code%TYPE
      , p_message_text                  IN user_message.message_text%TYPE
      ) 
   RETURN VARCHAR2;

   PROCEDURE select_table (p_user_message_table OUT g_tab_user_message) ;

   PROCEDURE select_row
      ( p_user_message_id      IN  USER_MESSAGE.user_message_id%TYPE 
      , p_rec_user_message     OUT USER_MESSAGE%ROWTYPE
      , p_row_md5              OUT VARCHAR
      ) ;

   PROCEDURE insert_row
      ( p_rec_user_message        IN  USER_MESSAGE%ROWTYPE
      , p_user_message_id         OUT USER_MESSAGE.user_message_id%TYPE
      , p_status_message          OUT VARCHAR2
      );

   PROCEDURE update_row
      ( p_rec_user_message      IN USER_MESSAGE%ROWTYPE -- new values are incoming
      , p_rec_md5               IN VARCHAR2
      ) 
      ;

   PROCEDURE delete_row
      ( p_user_message_id        IN  USER_MESSAGE.user_message_id%TYPE
      , p_rec_md5                IN  VARCHAR2
      );

   FUNCTION get_message_text
     ( p_code            IN USER_MESSAGE.code%TYPE ) 
     RETURN VARCHAR2;

   FUNCTION generate_code
     ( p_ref_application_domain_id      IN USER_MESSAGE.ref_application_domain_id%TYPE
     , p_ref_user_message_type_id       IN USER_MESSAGE.ref_user_message_type_id%TYPE
     ) RETURN VARCHAR2 ;
END TAPI_USER_MESSAGE;
/