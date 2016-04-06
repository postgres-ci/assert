drop schema assert cascade;

create schema assert;

create sequence assert.current_test;
create sequence assert.running_numbers;

create table assert.tests (
    test_id     serial  primary key,
    namespace   name    not null,
    procedure   name    not null check(procedure like 'test\_%'),
    created_at  timestamptz not null default current_timestamp
);

create unique index uidx_assert_test_func       on assert.tests (lower(namespace || '.' || procedure));

create type assert.error as (
    message  text,
    comment  text,
    context  text
);

create unlogged table assert.errors(
    test_id  int          not null references assert.tests(test_id),
    run_num  bigint       not null default currval('assert.running_numbers'),
    error    assert.error not null
);

create unlogged table assert.current_test_id(
    current_test int not null default currval('assert.current_test') primary key,
    test_id      int not null references assert.tests(test_id)
);

create table assert.results(
    test_id     int            not null references assert.tests(test_id),
    run_num     bigint         not null default currval('assert.running_numbers'),
    errors      assert.error[] not null default '{}',
    started_at  timestamptz    not null,
    finished_at timestamptz,
    primary key (run_num, test_id)
);