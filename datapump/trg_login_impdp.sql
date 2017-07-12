

CREATE OR REPLACE TRIGGER system.trg_login_impdp
  AFTER LOGON ON DATABASE

DECLARE
    server_host     varchar2(1000) := lower(SYS_CONTEXT('USERENV', 'HOST'));
    host            varchar2(1000) := lower(SYS_CONTEXT('USERENV', 'SERVER_HOST'));
    module          varchar2(1000) := lower(SYS_CONTEXT('USERENV', 'MODULE'));

    module_allowwd  varchar2(30)   := 'impdp';

BEGIN
    IF instr(server_host, '.') > 0 THEN
        server_host := substr(server_host, 1, instr(server_host, '.')-2);
    END IF;

    IF instr(host, '.') > 0 THEN
        host := substr(host, 1, instr(host, '.')-1);
    END IF;


    IF sys.login_user = 'IMPDP' THEN

        -- Login from host where oracle is running is allowrd
        -- => Requirred for administration of database link in SQLPlus
        if host = server_host 
          or instr(module, module_allowwd) = 1 THEN
            NULL;
        ELSE

            RAISE_APPLICATION_ERROR(-20001,'Login not allowed for user ' || user || ' with different hostname server_host: ' || server_host || ' host: ' || host || ' Module: ' || module || instr(module, module_allowwd));
        END IF;
    END IF;
END;
/
