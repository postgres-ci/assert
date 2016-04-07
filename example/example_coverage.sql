SELECT 
    namespace.nspname AS namespace,
    func.proname      AS procedure,
    CASE WHEN tests.proname IS NOT NULL 
        THEN '+' 
        ELSE '-' 
    END AS covered
FROM pg_proc func
JOIN pg_namespace namespace ON func.pronamespace = namespace.oid
LEFT JOIN pg_proc tests     ON func.pronamespace = tests.pronamespace 
    AND func.proname = RIGHT(tests.proname, -5)
WHERE namespace.nspname NOT LIKE 'pg_%'
AND   namespace.nspname NOT IN ('assert', 'information_schema')
AND   func.proname      NOT LIKE 'test_%';

/*

 namespace |  procedure  | covered 
-----------+-------------+---------
 example   | create_user | +
 example   | uncovered   | -

 */