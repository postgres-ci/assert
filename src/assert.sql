create schema assert;

create sequence assert.current_test;
create sequence assert.running_numbers;

create table assert.tests (
    test_id     serial  primary key,
    namespace   name    not null,
    procedure   name    not null check(procedure like 'test\_%'),
    created_at  timestamptz not null default current_timestamp
);

create unique index uidx_assert_test_func on assert.tests (lower(namespace || '.' || procedure));

create type assert.error as (
    message text,
    comment text
);

create unlogged table assert.errors(
    test_id  int          not null references assert.tests(test_id) on delete cascade,
    run_num  bigint       not null default currval('assert.running_numbers'),
    error    assert.error not null
);

create unlogged table assert.current_test_id(
    current_test int not null default currval('assert.current_test') primary key,
    test_id      int not null references assert.tests(test_id) on delete cascade
);

create table assert.results(
    test_id     int            not null references assert.tests(test_id) on delete cascade,
    run_num     bigint         not null default currval('assert.running_numbers'),
    errors      assert.error[] not null default '{}',
    started_at  timestamptz    not null,
    finished_at timestamptz,
    primary key (run_num, test_id)
);

create index idx_assert_test_results on assert.results(test_id);
/*
create or replace view assert.view_tests as 
    SELECT 
        T.test_id,
        T.namespace,
        T.procedure,
        T.created_at,
        R.started_at AS last_run_at,
        CASE 
            WHEN R.test_id IS NULL THEN '-'
            WHEN array_length(r.errors, 1) IS NULL THEN 'PASS'
            ELSE 'FAIL' 
        END AS last_result
    FROM assert.tests AS T 
    LEFT JOIN LATERAL (
        SELECT 
            R.test_id,
            R.errors, 
            R.started_at 
        FROM assert.results AS R 
        WHERE R.test_id = T.test_id 
        ORDER BY R.run_num DESC 
        LIMIT 1
    ) AS R USING(test_id);
*/