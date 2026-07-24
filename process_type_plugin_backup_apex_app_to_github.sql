--------------------------------------------------------------------------------
-- Copyright (c) 2024, 2026, AL-Malek.
--------------------------------------------------------------------------------
prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script using a SQL client connected to the database as
-- the owner (parsing schema) of the application or as a database user with the
-- APEX_ADMINISTRATOR_ROLE role.
--
-- This export file has been automatically generated. Modifying this file is not
-- supported by Oracle and can lead to unexpected application and/or instance
-- behavior now or in the future.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.0'
,p_default_workspace_id=>6201701268641295
,p_default_application_id=>105
,p_default_id_offset=>0
,p_default_owner=>'MEDICAL_CENTER_SYSTEM'
);
end;
/
 
prompt APPLICATION 105 - Medical Center System
--
-- Application Export:
--   Application:     105
--   Name:            Medical Center System
--   Date and Time:   22:42 Friday July 24, 2026
--   Exported By:     MEDICAL_CENTER_SYSTEM
--   Flashback:       0
--   Export Type:     Component Export
--   Manifest
--     PLUGIN: 79463379499478507
--   Manifest End
--   Version:         26.1.0
--   Instance ID:     2400113088921891
--

begin
  -- replace components
  wwv_flow_imp.g_mode := 'REPLACE';
end;
/
prompt --application/shared_components/plugins/process_type/backup_apex_app_to_github
begin
wwv_flow_imp_shared.create_plugin(
 p_id=>wwv_flow_imp.id(79463379499478507)
,p_plugin_type=>'PROCESS TYPE'
,p_name=>'BACKUP_APEX_APP_TO_GITHUB'
,p_display_name=>'Backup APEX App to GitHub'
,p_apexlang_name=>'backupApexAppToGithub'
,p_supported_component_types=>'APEX_APPLICATION_PAGE_PROC:APEX_APPL_AUTOMATION_ACTIONS:APEX_APPL_TASKDEF_ACTIONS:APEX_APPL_WORKFLOW_ACTIVITIES'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- ==================================================================',
'-- PLUGIN NAME      : Backup APEX Application to GitHub',
'-- INTERNAL NAME    : BACKUP_APEX_APP_TO_GITHUB',
'-- BY               : Malek M. Al-Edresi (Oracle ACE Associate)',
'-- ON DATE          : 2026-07-18 (Final)',
'-- TYPE             : Process Plugin',
'-- DESCRIPTION      : Exports an APEX application as a SQL file and',
'--                    uploads it to a GitHub repository via the REST API.',
'-- ==================================================================',
'',
'PROCEDURE backup_apex_app_to_github (',
'    p_process IN            apex_plugin.t_process,',
'    p_plugin  IN            apex_plugin.t_plugin,',
'    p_result  IN OUT NOCOPY apex_plugin.t_process_exec_result',
') IS',
'',
'    -- ==================================================================',
unistr('    -- A. Retrieve plugin attributes (mapped to custom attributes 01\201306)'),
'    -- ==================================================================',
'    l_app_id        NUMBER         := p_process.attribute_01;          -- Application ID',
'    l_github_token  VARCHAR2(4000) := p_process.attribute_02;          -- GitHub token',
'    l_repo_owner    VARCHAR2(200)  := p_process.attribute_03;          -- Owner',
'    l_repo_name     VARCHAR2(200)  := p_process.attribute_04;          -- Repo name',
'    l_branch        VARCHAR2(50)   := NVL(p_process.attribute_05, ''main''); -- Branch, default ''main''',
'    l_file_path     VARCHAR2(200)  := p_process.attribute_06;          -- Optional file path',
'',
'    -- ==================================================================',
'    -- B. Internal variables and helper function',
'    -- ==================================================================',
'    l_export_files  APEX_T_EXPORT_FILES;',
'    l_export_clob   CLOB;',
'    l_file_blob     BLOB;',
'    l_sha           VARCHAR2(200);',
'    l_json          CLOB;',
'    l_base64_content CLOB;',
'    l_blob_length   INTEGER;',
'    l_offset        INTEGER;',
'    l_buffer        RAW(19500);',
'    l_read_len      PLS_INTEGER;',
'    l_response      CLOB;',
'    l_full_repo     VARCHAR2(400);',
'    l_final_file_path VARCHAR2(200);',
'    l_status_code   NUMBER;',
'    l_error_msg     VARCHAR2(4000);',
'',
'    -- Helper function to get SHA of existing file (for update)',
'    FUNCTION get_github_sha RETURN VARCHAR2 IS',
'        l_resp CLOB;',
'        l_stat NUMBER;',
'    BEGIN',
'        apex_web_service.clear_request_headers;',
'        apex_web_service.set_request_headers(',
'            p_name_01 => ''Authorization'',',
'            p_value_01 => ''token '' || l_github_token,',
'            p_name_02 => ''User-Agent'',',
'            p_value_02 => ''Oracle-APEX''',
'        );',
'',
'        l_resp := apex_web_service.make_rest_request(',
'            p_url => ''https://api.github.com/repos/'' || l_full_repo || ''/contents/'' || l_final_file_path,',
'            p_http_method => ''GET''',
'        );',
'        l_stat := apex_web_service.g_status_code;',
'',
unistr('        -- File does not exist \2192 new file'),
'        IF l_stat = 404 THEN',
'            RAISE_APPLICATION_ERROR(-20004, ',
'                ''File '' || l_final_file_path || '' does not exist on GitHub. '' ||',
'                ''This plugin only updates existing files (no create).'');',
unistr('        -- File exists \2192 return its SHA'),
'        ELSIF l_stat = 200 THEN',
'            RETURN json_value(l_resp, ''$.sha'');',
unistr('        -- Any other HTTP error \2192 raise exception'),
'        ELSE',
'            l_error_msg := json_value(l_resp, ''$.message'');',
'            IF l_error_msg IS NULL THEN',
'                l_error_msg := ''HTTP '' || l_stat || '' from GitHub'';',
'            END IF;',
'            RAISE_APPLICATION_ERROR(-20002, ''Cannot check existing file: '' || l_error_msg);',
'        END IF;',
'    EXCEPTION',
unistr('        -- Unexpected errors (network, ACL, etc.) \2013 propagate them, don''t swallow.'),
'        WHEN OTHERS THEN',
'            RAISE;',
'    END get_github_sha;',
'',
'BEGIN',
'    -- ==================================================================',
'    -- C. Validate required inputs early',
'    -- ==================================================================',
'    IF l_app_id IS NULL OR l_app_id <= 0 THEN',
'        RAISE_APPLICATION_ERROR(-20001, ''Valid Application ID is required.'');',
'    END IF;',
'    IF l_github_token IS NULL OR LENGTH(l_github_token) < 10 THEN',
'        RAISE_APPLICATION_ERROR(-20001, ''A valid GitHub token is required.'');',
'    END IF;',
'    IF l_repo_owner IS NULL OR l_repo_name IS NULL THEN',
'        RAISE_APPLICATION_ERROR(-20001, ''Repository owner and name are required.'');',
'    END IF;',
'',
'    -- ==================================================================',
'    -- D. Build repository and final file path (handle empty path)',
'    -- ==================================================================',
'    l_full_repo := l_repo_owner || ''/'' || l_repo_name;',
'    IF l_file_path IS NULL OR l_file_path = '''' THEN',
'        l_final_file_path := ''apex/app_'' || l_app_id || ''_latest.sql'';',
'    ELSE',
'        l_final_file_path := l_file_path;',
'    END IF;',
'',
unistr('    -- Log start (masking token for security) \2013 use session debug flag'),
'    IF apex_application.g_debug THEN',
'        apex_debug.info(''Backup APEX App: Starting for app %s'', l_app_id);',
'        apex_debug.info(''Repo: %s, branch: %s, file: %s'', l_full_repo, l_branch, l_final_file_path);',
'        apex_debug.info(''Token (masked): %s...'', SUBSTR(l_github_token, 1, 4));',
'    END IF;',
'',
'    -- ==================================================================',
'    -- E. Export the APEX application as a single CLOB',
'    -- ==================================================================',
'    l_export_files := apex_export.get_application (',
'        p_application_id           => l_app_id,',
'        p_split                    => FALSE,',
'        p_with_date                => TRUE,',
'        p_with_ir_public_reports   => TRUE,',
'        p_with_ir_private_reports  => TRUE,',
'        p_with_ir_notifications    => TRUE,',
'        p_with_translations        => TRUE,',
'        p_with_no_subscriptions    => TRUE,',
'        p_with_original_ids        => TRUE ',
'    );',
'',
'    IF l_export_files.COUNT = 0 THEN',
'        RAISE_APPLICATION_ERROR(-20001, ''Application '' || l_app_id || '' not found.'');',
'    END IF;',
'',
'    l_export_clob := l_export_files(1).contents;',
'',
'    IF apex_application.g_debug THEN',
'        apex_debug.info(''Export successful, size: %s bytes'', DBMS_LOB.getlength(l_export_clob));',
'    END IF;',
'',
'    -- ==================================================================',
unistr('    -- F. Convert CLOB \2192 BLOB and encode to Base64 (chunked for large files)'),
'    -- ==================================================================',
'    l_file_blob := apex_util.clob_to_blob(l_export_clob);',
'    l_base64_content := '''';',
'    l_blob_length := DBMS_LOB.getlength(l_file_blob);',
'    l_offset := 1;',
'',
'    WHILE l_offset <= l_blob_length LOOP',
'        l_read_len := LEAST(19500, l_blob_length - l_offset + 1);',
'        DBMS_LOB.read(l_file_blob, l_read_len, l_offset, l_buffer);',
'        l_base64_content := l_base64_content || UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(l_buffer));',
'        l_offset := l_offset + 19500;',
'    END LOOP;',
'',
'    -- ==================================================================',
unistr('    -- G. Get SHA of existing file (if any) \2013 handles 404 and raises other errors'),
'    -- ==================================================================',
'    l_sha := get_github_sha;',
'',
'    -- ==================================================================',
'    -- H. Build JSON payload for GitHub API (PUT /contents)',
'    -- ==================================================================',
'    apex_json.initialize_clob_output;',
'    apex_json.open_object;',
'    apex_json.write(''message'', ''APEX backup '' || l_app_id || '' by Process Plugin'');',
'    -- Remove line breaks from Base64 content to meet GitHub API requirements',
'    apex_json.write(''content'', REPLACE(REPLACE(l_base64_content, CHR(10), ''''), CHR(13), ''''));',
'    IF l_sha IS NOT NULL THEN',
'        apex_json.write(''sha'', l_sha);',
'    END IF;',
'    apex_json.write(''branch'', l_branch);',
'    apex_json.close_object;',
'    l_json := apex_json.get_clob_output;',
'    apex_json.free_output;',
'',
'    -- ==================================================================',
'    -- I. Call GitHub API to create/update the file',
'    -- ==================================================================',
'    apex_web_service.clear_request_headers;',
'    apex_web_service.set_request_headers(',
'        p_name_01 => ''Authorization'',',
'        p_value_01 => ''token '' || l_github_token,',
'        p_name_02 => ''User-Agent'',',
'        p_value_02 => ''Oracle-APEX'',',
'        p_name_03 => ''Content-Type'',',
'        p_value_03 => ''application/json''',
'    );',
'',
'    l_response := apex_web_service.make_rest_request(',
'        p_url => ''https://api.github.com/repos/'' || l_full_repo || ''/contents/'' || l_final_file_path,',
'        p_http_method => ''PUT'',',
'        p_body => l_json',
'    );',
'',
'    -- ==================================================================',
unistr('    -- J. Check HTTP status code \2013 raise error if not 200 or 201'),
'    -- ==================================================================',
'    l_status_code := apex_web_service.g_status_code;',
'    IF l_status_code NOT IN (200, 201) THEN',
'        l_error_msg := json_value(l_response, ''$.message'');',
'        IF l_error_msg IS NULL THEN',
'            l_error_msg := ''HTTP '' || l_status_code || '' from GitHub'';',
'        END IF;',
'        RAISE_APPLICATION_ERROR(-20003, ''GitHub upload failed: '' || l_error_msg);',
'    END IF;',
'',
'    -- ==================================================================',
'    -- K. Set success message (include direct link to the file)',
'    -- ==================================================================',
'    p_result.success_message := ',
'        ''Application '' || l_app_id || '' backed up to '' ||',
'        l_full_repo || ''/blob/'' || l_branch || ''/'' || l_final_file_path || ',
'        '' (commit pending)'';',
'',
'    IF apex_application.g_debug THEN',
'        apex_debug.info(''Backup completed successfully for app %s'', l_app_id);',
'    END IF;',
'',
'EXCEPTION',
'    -- ==================================================================',
'    -- L. On any error, log it and re-raise so APEX marks process as failed',
'    -- ==================================================================',
'    WHEN OTHERS THEN',
'        IF apex_application.g_debug THEN',
'            apex_debug.error(''Backup APEX App failed: %s'', SQLERRM);',
'        END IF;',
'        RAISE;',
'END backup_apex_app_to_github;',
''))
,p_api_version=>3
,p_execution_function=>'backup_apex_app_to_github'
,p_version_scn=>'SH256:AJ446Q9hN4tGAWITCUVq1TtvXHAi3MuKWtC5OYEMeJQ'
,p_help_text=>'Backup APEX App to GitHub is an Oracle APEX Process Plugin that automatically exports an APEX application as a SQL file and uploads it to a GitHub repository using the GitHub REST API. It supports creating or updating files, private repositories, con'
||unistr('figurable branches and file paths, secure token handling, and detailed error reporting\2014making it ideal for version control, backups, and CI/CD workflows. Developed by Eng. Malek M. Al-Edresi (Oracle ACE Associate).')
,p_version_identifier=>'1.0'
,p_about_url=>'https://github.com/malek-al-edresi/apex-backup-app-to-github-process-plugin'
,p_plugin_comment=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Author: Eng. Malek M. Al-Edresi (Oracle ACE Associate) ',
'Backup APEX app to GitHub via REST API. ',
'Requires: GitHub token (repo scope), ACL to api.github.com:443.',
'Supports create/update mode. Debug logging available.'))
,p_files_version=>2461240204116
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79463983080520420)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_static_id=>'application_id'
,p_prompt=>'Application ID'
,p_apexlang_name=>'applicationId'
,p_attribute_type=>'NUMBER'
,p_is_required=>true
,p_default_value=>':APP_ID'
,p_is_translatable=>false
,p_examples=>'100'
,p_help_text=>'The numeric ID of the APEX application you want to back up. Found in the application''s "Shared Components" or the URL.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79466680743539671)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_static_id=>'branch'
,p_prompt=>'Branch'
,p_apexlang_name=>'branch'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'main or develop'
,p_help_text=>'The branch where the backup file will be committed. If left blank, defaults to main.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79467223162543937)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_static_id=>'file_path'
,p_prompt=>'File Path'
,p_apexlang_name=>'filePath'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'backups/app_100.sql'
,p_help_text=>'Optional custom path/filename within the repository. If left blank, the plugin uses apex/app_#APP_ID#_latest.sql. You may include substitution strings like #APP_ID#.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79464807567529469)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_static_id=>'github_token'
,p_prompt=>'GitHub Token'
,p_apexlang_name=>'githubToken'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'ghp_xxxxxxxxxxxxxxxxxxxx'
,p_help_text=>unistr('Personal access token with repo or content write permissions. Generate at GitHub Settings \2192 Developer settings \2192 Personal access tokens \2192 Tokens (classic).')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79466085315537218)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_static_id=>'repository_name'
,p_prompt=>'Repository Name'
,p_apexlang_name=>'repositoryName'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'my-repo'
,p_help_text=>'The exact name of the repository (without the owner).'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(79465481072534033)
,p_plugin_id=>wwv_flow_imp.id(79463379499478507)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_static_id=>'repository_owner'
,p_prompt=>'Repository Owner'
,p_apexlang_name=>'repositoryOwner'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'my-username'
,p_help_text=>'The GitHub username or organization that owns the target repository.'
);
end;
/
prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false)
);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
