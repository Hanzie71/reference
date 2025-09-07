create or replace PACKAGE dd_create_objects AS
--  ============================================================================
--  PACKAGE            : DD_CREATE_OBJECTS
--
--  FUNCTION:
--      Supports development
--
--  PURPOSE:
--
--      Utilities to support type-first development in Oracle APEX
--
--      This package will be called from a script. It create objects for scheme
--      based on tables in that scheme
--
--  CREATED BY         : Hans Blok
--
--  CHANGE LOG:
--      30-Apr-2025   HB   Initial creation
--      14-May-2025   HB   Initial creation
--      20-Jun-2025   HB   Procedure added for creating sysnonyms 
--                                    on DDVB packages, procedures and functions
--
--
--  PUBLIC PROCEDURES:
--    ✅ prepare_create_tables
--         - disable FK contraints so tables can be dropped (for scheme VB)
--         - drops the tables (for scheme VB)
--
--    ✅ after_create_tables
--         - creates seqeunces (after dropping them)
--         - creates the types (based on the tables)
--         - populates REF_TABLES (insert)
--         - compiles the packages, procedures and views
--         - enables all FK-constraints in scheme VB
--
--  SUGGESTIONS (FUTURE):
--         - introduce a parameter for the scheme
--
-- ============================================================================
   PROCEDURE prepare_create_tables;
   PROCEDURE after_create_tables;
  
   PROCEDURE create_seqs (p_start_with NUMBER DEFAULT 100); 
   PROCEDURE create_types ;
   PROCEDURE create_dd_synonyms (p_target_schema IN VARCHAR2) ;
   PROCEDURE disable_foreign_keys ;
   PROCEDURE enable_foreign_keys ;
   PROCEDURE compile_all_pkgs ;
   
END dd_create_objects;
/