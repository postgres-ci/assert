package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"log"
	"strings"
)

type Test struct {
	Test   string `db:"test"`
	Result string `db:"result"`
	Errors Errors `db:"errors"`
}

type Error struct {
	Error       string `json:"error"`
	Description string `json:"description"`
	Context     string `json:"context"`
}

type Errors []Error

type postgres struct {
	Host     string `yaml:"host"`
	Port     int64  `yaml:"port"`
	Username string `yaml:"username"`
	Password string `yaml:"password"`
	Database string `yaml:"database"`
}

func (p *postgres) DataSourceName() string {

	if p.Port != 0 {

		return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", p.Host, p.Port, p.Username, p.Password, p.Database)
	}

	return fmt.Sprintf("host=%s  user=%s password=%s dbname=%s sslmode=disable", p.Host, p.Username, p.Password, p.Database)
}

var config postgres

func (e *Errors) Scan(src interface{}) error {

	var source []byte

	switch src.(type) {

	case string:

		source = []byte(src.(string))

	case []byte:

		source = src.([]byte)

	default:

		return fmt.Errorf("Incompatible type for Errors")
	}

	return json.Unmarshal(source, &e)
}

func init() {

	flag.StringVar(&config.Host, "h", "/var/run/postgresql", "")
	flag.Int64Var(&config.Port, "p", 0, "")
	flag.StringVar(&config.Username, "U", "postgres", "")
	flag.StringVar(&config.Password, "W", "", "")
	flag.StringVar(&config.Database, "d", "", "")
}

func main() {

	flag.Parse()

	connect := sqlx.MustOpen("postgres", config.DataSourceName())

	var tests []Test

	if err := connect.Select(&tests, "SELECT test, result, errors FROM assert.TestRunner()"); err == nil {

		fmt.Printf("1..%d\n", len(tests))

		for num, test := range tests {

			switch test.Result {
			case "PASS":
				fmt.Printf("ok %d - %s\n", num+1, test.Test)
			case "FAIL":

				errors := make([]string, len(test.Errors))

				for _, error := range test.Errors {

					errors = append(errors, fmt.Sprintf("%s. %s", error.Error, error.Description))
				}

				fmt.Printf("not ok %d - %s #%s\n", num+1, test.Test, strings.Join(errors, ". "))
			}
		}

	} else {

		log.Fatal(err)
	}
}
