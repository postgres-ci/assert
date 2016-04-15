create or replace function assert.exception(
    sql                  text,
    comment              text default '',
    exception_table      text default '',
    exception_column     text default '',
    exception_schema     text default '',
    exception_message    text default '',
    exception_sqlstate   text default '',
    exception_constraint text default ''
) returns boolean as $$
    declare 
        _column_name     text;
        _constraint_name text;
        _table_name      text;
        _schema_name     text;
    begin 
        BEGIN 
            EXECUTE sql;
        EXCEPTION WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS 
                _table_name      = table_name,
                _column_name     = column_name,
                _schema_name     = schema_name,
                _constraint_name = constraint_name;

            CASE
                WHEN exception_table NOT IN ('', _table_name) THEN 
                    return assert.fail(format('Table name not equal: %s (expected) != %s (actual)', exception_table, _table_name), comment);
                WHEN exception_column NOT IN ('', _column_name) THEN 
                    return assert.fail(format('Column name not equal: %s (expected) != %s (actual)', exception_column, _column_name), comment);
                WHEN exception_schema NOT IN ('', _schema_name) THEN 
                    return assert.fail(format('Schema name not equal: %s (expected) != %s (actual)', exception_schema, _schema_name), comment);
                WHEN exception_message NOT IN ('', SQLERRM) THEN 
                    return assert.fail(format('Message not equal: %s (expected) != %s (actual)', exception_message, SQLERRM), comment);
                WHEN exception_sqlstate NOT IN ('', SQLSTATE) THEN 
                    return assert.fail(format('SqlState not equal: %s (expected) != %s (actual)', exception_sqlstate, SQLSTATE), comment);
                WHEN exception_constraint NOT IN ('', _constraint_name) THEN 
                    return assert.fail(format('Constraint name not equal: %s (expected) != %s (actual)', exception_constraint, _constraint_name), comment);
                ELSE 
                    return true;
            END CASE;
        END;

        return assert.fail('No exception thrown', comment);
    end;
$$ language plpgsql security definer;