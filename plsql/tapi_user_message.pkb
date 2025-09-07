create or replace PACKAGE BODY TAPI_USER_MESSAGE AS 
-- =============================================================================
--
--  CHANGE LOG:
--      23-Apr-2025   HB   Initial creation
--
-- =============================================================================    

   -- --------------------------------------------------------------------------
   -- Private
   -- 
   -- Purpose
   --    calling proc isn ddvb-schema for logging audit data 
   --    this procedure has knowledge of the table (concern of the TAPI)
   --    and the exernal proc for logging
   -- --------------------------------------------------------------------------
   PROCEDURE log_action
      ( p_mdl_calling_proc     IN  VARCHAR2                                
      , p_rec_user_message     IN  USER_MESSAGE%ROWTYPE
      ) 
   IS
     l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
     l_tab_audit_log_clmn  TAPI_AUDIT_LOG.audit_log_clmn_tab;

   BEGIN     

      dl('🔍', '▶️', l_mdl);
      
      l_tab_audit_log_clmn(1).clmn := 'ref_application_domain_id';
      l_tab_audit_log_clmn(1).vlu  := p_rec_user_message.ref_application_domain_id ;

      l_tab_audit_log_clmn(2).clmn := 'ref_user_message_type_id';
      l_tab_audit_log_clmn(3).vlu  := p_rec_user_message.ref_user_message_type_id ;

      l_tab_audit_log_clmn(3).clmn := 'code';
      l_tab_audit_log_clmn(3).vlu  := p_rec_user_message.code ;
     
      l_tab_audit_log_clmn(4).clmn := 'message_text';
      l_tab_audit_log_clmn(4).vlu  := p_rec_user_message.message_text ;
      
      TAPI_AUDIT_LOG.log_audit(p_mdl_calling_proc, p_rec_user_message.user_message_id,  l_tab_audit_log_clmn);

  END log_action ;

-- ------------------------------------------------------------------------                                                                 
-- purpose
--   to define a hash-string for a row
--   used for optimistic locking
------------------------------------------------------------------------
   FUNCTION md5_row 
      ( p_ref_application_domain_id     IN user_message.ref_application_domain_id%TYPE
      , p_ref_user_message_type_id      IN user_message.ref_user_message_type_id%TYPE
      , p_code                          IN user_message.code%TYPE
      , p_message_text                  IN user_message.message_text%TYPE
      ) RETURN VARCHAR2 
   IS
   
   c_col_sep  CONSTANT VARCHAR2(1) := '|';

   BEGIN     

    -- logging debug info with dl-function is not possible because of using the function by creating the view 
    -- a transaction is not allowed by viewing data using a view

      RETURN hash_string 
         ( NVL(TO_CHAR(p_ref_application_domain_id),0)     || c_col_sep ||     
           NVL(TO_CHAR(p_ref_user_message_type_id),0)      || c_col_sep ||     
           NVL(TO_CHAR(p_code),0)                          || c_col_sep ||
           NVL(TO_CHAR(p_message_text),0)                  || c_col_sep ||                                                                    
           '' 
        );

    END md5_row;

   -- ------------------------------------------------------------------------                                                                 
   -- purpose 
   --   to define a hash-string for a row
   --   used for optimistic locking
   ------------------------------------------------------------------------

   FUNCTION has_childs ( p_user_message_id       user_message.user_message_id%TYPE ) 
   RETURN BOOLEAN  
   IS
      l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
     l_count                INTEGER;
      l_has_childs           BOOLEAN;
   BEGIN
       dl('🔍', '▶️', l_mdl);
      -- when child-table is defined, look for childs for te row to be deleted
	   -- if childs exist, delete is not allowed
       
       -- call TAPI_KLANT_DIEET           for rows with incoming p_user_message_id
       -- call TAPI_PAKKET_UITGIFTE_DIEET for rows with incoming p_user_message_id
	  l_has_childs := TRUE;
      RETURN l_has_childs;
   END has_childs;

   -- --------------------------------------------------------------------------
   -- Public
   --
   -- Purpose     : 
   --   - select message
   --   - log selecting of message
   --
   -- --------------------------------------------------------------------------
   -- Implementation of get_message function
   FUNCTION get_message_text 
     ( p_code            IN USER_MESSAGE.code%TYPE ) 
   RETURN VARCHAR2
   IS
     
     l_message_text      USER_MESSAGE.message_text%TYPE ;
     l_user_message_id   USER_MESSAGE.user_message_id%TYPE ;
     
     PRAGMA AUTONOMOUS_TRANSACTION;    
   
   BEGIN
      
    -- Retrieve the message
    BEGIN
      SELECT user_message_id
           , message_text
        INTO l_user_message_id
           , l_message_text
        FROM USER_MESSAGE
       WHERE code = p_code
       ;
      
      -- Log the message access
      INSERT INTO USER_MESSAGE_LOG 
         ( user_message_log_id
         , user_message_id
         , user_name
         , businessunit_id
         , log_datetime
         ) VALUES 
         ( USER_MESSAGE_LOG_SEQ.NEXTVAL
         , l_user_message_id
         , v('APP_USER')
         , v('BUSINESSUNIT_ID')
         , SYSDATE
       );
            
      COMMIT ;

      RETURN l_message_text;
      
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- No message found for the given parameters
        RETURN 'Gebruikersmelding niet gevonden voor code: ' || p_code;
      WHEN OTHERS THEN
        -- Log the error and return error message
        RETURN 'Error retrieving message: ' || SQLERRM;
    END;
   END get_message_text;

-- --------------------------------------------------------------------------
   -- Private
   --
   -- Purpose     : 
   --   - determine code for update and insert
   --
   -- --------------------------------------------------------------------------
   
    FUNCTION generate_code
     ( p_ref_application_domain_id      IN USER_MESSAGE.ref_application_domain_id%TYPE
     , p_ref_user_message_type_id       IN USER_MESSAGE.ref_user_message_type_id%TYPE
     ) RETURN VARCHAR2 IS
      l_rec_ref_application_domain REF_APPLICATION_DOMAIN%ROWTYPE;
      l_rec_ref_user_message_type  REF_USER_MESSAGE_TYPE%ROWTYPE;
      l_prefix                     VARCHAR2(2);
      l_suffix                     VARCHAR2(2);
      l_full_code                  VARCHAR2(4);
      l_exists                     NUMBER;
   BEGIN
   
      TAPI_REF_APPLICATION_DOMAIN.select_row
              ( p_ref_application_domain_id
              , l_rec_ref_application_domain -- out
              );  
   
      TAPI_REF_USER_MESSAGE_TYPE.select_row
              ( p_ref_user_message_type_id
              , l_rec_ref_user_message_type -- out
              );  
      
      l_prefix := TO_CHAR(l_rec_ref_application_domain.code) || TO_CHAR(l_rec_ref_user_message_type.code);

   FOR i IN 0 .. 99 LOOP
      l_suffix := LPAD(i, 2, '0');  -- always 2 digits: 00, 01, ..., 99
      l_full_code := l_prefix || l_suffix;

     SELECT COUNT(1) INTO l_exists
       FROM USER_MESSAGE
       WHERE code = l_full_code;

      IF l_exists = 0 THEN
         RETURN l_full_code;
      END IF;
   END LOOP;

   RETURN NULL; -- fallback if all 100 codes are used
END generate_code;

-- ------------------------------------------------------------------------                                                                 
-- Public
--
-- Purpose 
--   to select all values of al rows in the table
------------------------------------------------------------------------

   PROCEDURE select_table (p_user_message_table OUT g_tab_user_message) 
   IS
      l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
   BEGIN
      -- no logging because this procedure is called as part of a SELECT
      -- then transactions are not allowed
      
      SELECT user_message_id
           , ref_application_domain_id
           , ref_user_message_type_id
           , code
           , message_text
        BULK COLLECT INTO p_user_message_table
        FROM USER_MESSAGE;
  
   END select_table ;           

-- ------------------------------------------------------------------------                                                                 
--   Public
--
--   Purpose 
--     to select values for a row for PK, hash included
------------------------------------------------------------------------

   PROCEDURE select_row
      ( p_user_message_id      IN  USER_MESSAGE.user_message_id%TYPE 
      , p_rec_user_message     OUT USER_MESSAGE%ROWTYPE
      , p_row_md5              OUT VARCHAR
      ) 
   IS
      l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
      l_rec_user_message  USER_MESSAGE%ROWTYPE;
      l_row_md5           VARCHAR2(64);
   BEGIN     

      dl('🔍', '▶️', l_mdl);

       SELECT user_message_id  
           , ref_application_domain_id
           , ref_user_message_type_id
           , code
           , message_text
           , md5_row(ref_application_domain_id,ref_user_message_type_id,code,message_text) AS md5_row
        INTO l_rec_user_message.user_message_id  
           , l_rec_user_message.ref_application_domain_id
           , l_rec_user_message.ref_user_message_type_id
           , l_rec_user_message.code  
           , l_rec_user_message.message_text
           , l_row_md5
           FROM USER_MESSAGE
     WHERE user_message_id  =  p_user_message_id
     ;
    
     p_rec_user_message   := l_rec_user_message ;
     p_row_md5            := l_row_md5;

  END select_row;


-- ------------------------------------------------------------------------                                                                 
-- purpose 
--   to create a row (with correct id for PK) 
------------------------------------------------------------------------
   PROCEDURE insert_row
   ( p_rec_user_message      IN  USER_MESSAGE%ROWTYPE
   , p_user_message_id       OUT USER_MESSAGE.user_message_id%TYPE
   , p_status_message        OUT VARCHAR2
   )  
   AS 
      l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
      l_status_message     VARCHAR2(2000) := '';
      l_rec_user_message   USER_MESSAGE%ROWTYPE ;                     -- #log audit
      l_user_message_id    USER_MESSAGE.user_message_id%TYPE ;
      l_exists_unique_key  BOOLEAN ;
      l_code               USER_MESSAGE.code%TYPE ;
      
   BEGIN
      dl('🔍', '▶️', l_mdl);
	   p_status_message := l_status_message;
      
       -- defining local record as parameter cannot be used as parameter for calling function 
       -- log_action uses this parameter 
      l_rec_user_message := p_rec_user_message ;
     
      l_code  :=  generate_code
                       ( l_rec_user_message.ref_application_domain_id
                       , l_rec_user_message.ref_user_message_type_id );

       INSERT 
         INTO USER_MESSAGE
           ( user_message_id
           , ref_application_domain_id
           , ref_user_message_type_id
           , code
           , message_text 
           ) 
       VALUES 
          ( user_message_seq.NEXTVAL 
          , l_rec_user_message.ref_application_domain_id
          , l_rec_user_message.ref_user_message_type_id
          , l_code
          , l_rec_user_message.message_text
          )
      RETURNING user_message_id INTO l_user_message_id;
         p_status_message := 'Succesfully saved.';
      
        l_rec_user_message.user_message_id := l_user_message_id ;  -- #log audit
        log_action (l_mdl, l_rec_user_message);              -- #log audit
        -- fill the out-parameter  
        p_user_message_id := l_user_message_id ;
      EXCEPTION
        WHEN OTHERS THEN
        BEGIN
           p_user_message_id := -1;
           p_status_message := SQLERRM;
           RAISE_APPLICATION_ERROR (-20000, p_status_message);
       END;
   END insert_row;

   -- ------------------------------------------------------------------------                                                                 
   --    Public
   --
   --    Purpose 
   --       update table (agnostic from proces)
   --       and performing optimistic locking
   ------------------------------------------------------------------------ 
   PROCEDURE update_row
      ( p_rec_user_message      IN USER_MESSAGE%ROWTYPE -- new values are incoming
      , p_rec_md5               IN VARCHAR2
      ) 
   IS
      l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
      l_rec_user_message        USER_MESSAGE%ROWTYPE;-- values in de database just before update
      l_row_md5                 VARCHAR2(64);
      l_code                    USER_MESSAGE.code%TYPE;
      l_exists_unique_key       BOOLEAN;
   BEGIN

      dl('🔍', '▶️', l_mdl);

      
     select_row
       ( p_rec_user_message.user_message_id    -- in
       , l_rec_user_message                 -- out
       , l_row_md5                       -- out 
       );

      l_code  :=  generate_code
                       ( p_rec_user_message.ref_application_domain_id
                       , p_rec_user_message.ref_user_message_type_id );

      
      IF NVL(l_row_md5,0) <>  NVL(p_rec_md5,0) -- comparing md5 with md5 when loading the record in the form
      THEN 
   	     UMSG.raise_user_error ('3101');
      END IF;

      UPDATE USER_MESSAGE
         SET ref_application_domain_id  = p_rec_user_message.ref_application_domain_id
           , ref_user_message_type_id   = p_rec_user_message.ref_user_message_type_id
           , code                       = l_code
           , message_text               = p_rec_user_message.message_text
       WHERE user_message_id = p_rec_user_message.user_message_id;

       log_action (l_mdl, p_rec_user_message);  -- #log audit

   END update_row;

   PROCEDURE delete_row
      ( p_user_message_id   IN USER_MESSAGE.user_message_id%TYPE
      , p_rec_md5           IN VARCHAR2                
      )
    AS
       l_mdl                 CONSTANT UTILS.mdl_string := UTILS.mdl(DBMS_UTILITY.format_call_stack);
       l_row                 USER_MESSAGE%ROWTYPE;
       l_row_md5             VARCHAR2(64);
   BEGIN

      dl('🔍', '▶️', l_mdl);

      select_row
         ( p_user_message_id 
         , l_row           -- out
         , l_row_md5       -- out
         );

      -- ------------------------------------------------------------------
      -- ADD CODE: CHECK ON EXISTING CHILDS IF TABLE HAS CHILD-TABLE(s)
      -- ------------------------------------------------------------------
      
      IF NVL(l_row_md5,0) = NVL(p_rec_md5,0)
      THEN
         DELETE 
           FROM USER_MESSAGE
          WHERE user_message_id = p_user_message_id;
      ELSE 
         UMSG.raise_user_error('3101');
      END IF;

      log_action (l_mdl, l_row);  -- #log audit

   END delete_row;

END TAPI_USER_MESSAGE;
/