#!/usr/bin/env ./tcltestrunner.lua

# 2008-10-04
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl
set ::testprefix indexedby

# Create a schema with some indexes.
#
do_test indexedby-1.1 {
  execsql {
    CREATE TABLE t1(id primary key, a, b);
    CREATE INDEX i1 ON t1(a);
    CREATE INDEX i2 ON t1(b);

    CREATE TABLE t2(id primary key, c, d);
    CREATE INDEX i3 ON t2(c);
    CREATE INDEX i4 ON t2(d);

    CREATE TABLE t3(e PRIMARY KEY, f);

    CREATE VIEW v1 AS SELECT * FROM t1;
  }
} {}

# Explain Query Plan
#
proc EQP {sql} {
  uplevel "execsql {EXPLAIN QUERY PLAN $sql}"
}

# These tests are to check that "EXPLAIN QUERY PLAN" is working as expected.
#
do_execsql_test indexedby-1.2 {
  EXPLAIN QUERY PLAN select * from t1 WHERE a = 10; 
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_1_i1 (a=?)}}
do_execsql_test indexedby-1.3 {
  EXPLAIN QUERY PLAN select * from t1 ; 
} {0 0 0 {SCAN TABLE t1}}
do_execsql_test indexedby-1.4 {
  EXPLAIN QUERY PLAN select * from t1, t2 WHERE c = 10; 
} {
  0 0 1 {SEARCH TABLE t2 USING COVERING INDEX 522_1_i3 (c=?)} 
  0 1 0 {SCAN TABLE t1}
}

# Parser tests. Test that an INDEXED BY or NOT INDEX clause can be 
# attached to a table in the FROM clause, but not to a sub-select or
# SQL view. Also test that specifying an index that does not exist or
# is attached to a different table is detected as an error.
#
# EVIDENCE-OF: R-07004-11522 -- syntax diagram qualified-table-name
# 
# EVIDENCE-OF: R-58230-57098 The "INDEXED BY index-name" phrase
# specifies that the named index must be used in order to look up values
# on the preceding table.
#
# do_test indexedby-2.1 {
#   execsql { SELECT * FROM t1 NOT INDEXED WHERE a = 'one' AND b = 'two'}
# } {}
# do_test indexedby-2.1b {
#   execsql { SELECT * FROM main.t1 NOT INDEXED WHERE a = 'one' AND b = 'two'}
# } {}
do_test indexedby-2.2 {
  execsql { SELECT * FROM t1 INDEXED BY '517_1_i1' WHERE a = 'one' AND b = 'two'}
} {}
do_test indexedby-2.2b {
  execsql { SELECT * FROM main.t1 INDEXED BY '517_1_i1' WHERE a = 'one' AND b = 'two'}
} {}
do_test indexedby-2.3 {
  execsql { SELECT * FROM t1 INDEXED BY '517_2_i2' WHERE a = 'one' AND b = 'two'}
} {}
# EVIDENCE-OF: R-44699-55558 The INDEXED BY clause does not give the
# optimizer hints about which index to use; it gives the optimizer a
# requirement of which index to use.
# EVIDENCE-OF: R-15800-25719 If index-name does not exist or cannot be
# used for the query, then the preparation of the SQL statement fails.
#
do_test indexedby-2.4 {
  catchsql { SELECT * FROM t1 INDEXED BY '522_1_i3' WHERE a = 'one' AND b = 'two'}
} {1 {no such index: 522_1_i3}}

# EVIDENCE-OF: R-62112-42456 If the query optimizer is unable to use the
# index specified by the INDEX BY clause, then the query will fail with
# an error.
# do_test indexedby-2.4.1 {
#   catchsql { SELECT b FROM t1 INDEXED BY '517_1_i1' WHERE b = 'two' }
# } {1 {no query solution}}

do_test indexedby-2.5 {
  catchsql { SELECT * FROM t1 INDEXED BY i5 WHERE a = 'one' AND b = 'two'}
} {1 {no such index: i5}}
do_test indexedby-2.6 {
  catchsql { SELECT * FROM t1 INDEXED BY WHERE a = 'one' AND b = 'two'}
} {1 {near "WHERE": syntax error}}
do_test indexedby-2.7 {
  catchsql { SELECT * FROM v1 INDEXED BY '517_1_i1' WHERE a = 'one' }
} {1 {no such index: 517_1_i1}}


# Tests for single table cases.
#
# EVIDENCE-OF: R-37002-28871 The "NOT INDEXED" clause specifies that no
# index shall be used when accessing the preceding table, including
# implied indices create by UNIQUE and PRIMARY KEY constraints. However,
# the rowid can still be used to look up entries even when "NOT INDEXED"
# is specified.
#
# do_execsql_test indexedby-3.1 {
#   EXPLAIN QUERY PLAN SELECT * FROM t1 WHERE a = 'one' AND b = 'two'
# } {/SEARCH TABLE t1 USING INDEX/}
# do_execsql_test indexedby-3.1.1 {
#   EXPLAIN QUERY PLAN SELECT * FROM t1 NOT INDEXED WHERE a = 'one' AND b = 'two'
# } {0 0 0 {SCAN TABLE t1}}
# do_execsql_test indexedby-3.1.2 {
#   EXPLAIN QUERY PLAN SELECT * FROM t1 NOT INDEXED WHERE rowid=1
# } {/SEARCH TABLE t1 USING INTEGER PRIMARY KEY .rowid=/}


do_execsql_test indexedby-3.2 {
  EXPLAIN QUERY PLAN 
  SELECT * FROM t1 INDEXED BY '517_1_i1' WHERE a = 'one' AND b = 'two'
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_1_i1 (a=?)}}
do_execsql_test indexedby-3.3 {
  EXPLAIN QUERY PLAN 
  SELECT * FROM t1 INDEXED BY '517_2_i2' WHERE a = 'one' AND b = 'two'
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_2_i2 (b=?)}}
# do_test indexedby-3.4 {
#   catchsql { SELECT * FROM t1 INDEXED BY '517_2_i2' WHERE a = 'one' }
# } {1 {no query solution}}
# do_test indexedby-3.5 {
#   catchsql { SELECT * FROM t1 INDEXED BY '517_2_i2' ORDER BY a }
# } {1 {no query solution}}
do_test indexedby-3.6 {
  catchsql { SELECT * FROM t1 INDEXED BY '517_1_i1' WHERE a = 'one' }
} {0 {}}
do_test indexedby-3.7 {
  catchsql { SELECT * FROM t1 INDEXED BY '517_1_i1' ORDER BY a }
} {0 {}}

# do_execsql_test indexedby-3.8 {
#   EXPLAIN QUERY PLAN 
#   SELECT * FROM t3 INDEXED BY sqlite_autoindex_t3_1 ORDER BY e 
# } {0 0 0 {SCAN TABLE t3 USING INDEX sqlite_autoindex_t3_1}}
# do_execsql_test indexedby-3.9 {
#   EXPLAIN QUERY PLAN 
#   SELECT * FROM t3 INDEXED BY sqlite_autoindex_t3_1 WHERE e = 10 
# } {0 0 0 {SEARCH TABLE t3 USING INDEX sqlite_autoindex_t3_1 (e=?)}}
# do_test indexedby-3.10 {
#   catchsql { SELECT * FROM t3 INDEXED BY sqlite_autoindex_t3_1 WHERE f = 10 }
# } {1 {no query solution}}
# do_test indexedby-3.11 {
#   catchsql { SELECT * FROM t3 INDEXED BY sqlite_autoindex_t3_2 WHERE f = 10 }
# } {1 {no such index: sqlite_autoindex_t3_2}}

# Tests for multiple table cases.
#
do_execsql_test indexedby-4.1 {
  EXPLAIN QUERY PLAN SELECT * FROM t1, t2 WHERE a = c 
} {
  0 0 0 {SCAN TABLE t1} 
  0 1 1 {SEARCH TABLE t2 USING COVERING INDEX 522_1_i3 (c=?)}
}
do_execsql_test indexedby-4.2 {
  EXPLAIN QUERY PLAN SELECT * FROM t1 INDEXED BY '517_1_i1', t2 WHERE a = c 
} {
  0 0 1 {SCAN TABLE t2} 
  0 1 0 {SEARCH TABLE t1 USING COVERING INDEX 517_1_i1 (a=?)}
}
# do_test indexedby-4.3 {
#   catchsql {
#     SELECT * FROM t1 INDEXED BY '517_1_i1', t2 INDEXED BY '522_1_i3' WHERE a=c
#   }
# } {1 {no query solution}}
# do_test indexedby-4.4 {
#   catchsql {
#     SELECT * FROM t2 INDEXED BY '522_1_i3', t1 INDEXED BY '517_1_i1' WHERE a=c
#   }
# } {1 {no query solution}}

# Test embedding an INDEXED BY in a CREATE VIEW statement. This block
# also tests that nothing bad happens if an index refered to by
# a CREATE VIEW statement is dropped and recreated.
#
do_execsql_test indexedby-5.1 {
  CREATE VIEW v2 AS SELECT * FROM t1 INDEXED BY '517_1_i1' WHERE a > 5;
  EXPLAIN QUERY PLAN SELECT * FROM v2 
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_1_i1 (a>?)}}
do_execsql_test indexedby-5.2 {
  EXPLAIN QUERY PLAN SELECT * FROM v2 WHERE b = 10 
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_1_i1 (a>?)}}
do_test indexedby-5.3 {
  execsql { DROP INDEX '517_1_i1' }
  catchsql { SELECT * FROM v2 }
} {1 {no such index: 517_1_i1}}

# MUST_WORK_TEST

do_test indexedby-5.4 {
  # Recreate index i1 in such a way as it cannot be used by the view query.
  execsql { CREATE INDEX i1 ON t1(b) }
  catchsql { SELECT * FROM v2 }
} {1 {no query solution}}

# MUST_WORK_TEST

do_test indexedby-5.5 {
  # Drop and recreate index i1 again. This time, create it so that it can
  # be used by the query.
  execsql { DROP INDEX '517_3_i1' ; CREATE INDEX i1 ON t1(a) }
  catchsql { SELECT * FROM v2 }
} {0 {}}

# # Test that "NOT INDEXED" may use the rowid index, but not others.
# # 
# do_execsql_test indexedby-6.1 {
#   EXPLAIN QUERY PLAN SELECT * FROM t1 WHERE b = 10 ORDER BY rowid 
# } {0 0 0 {SEARCH TABLE t1 USING INDEX i2 (b=?)}}
# do_execsql_test indexedby-6.2 {
#   EXPLAIN QUERY PLAN SELECT * FROM t1 NOT INDEXED WHERE b = 10 ORDER BY rowid 
# } {0 0 0 {SCAN TABLE t1}}

# EVIDENCE-OF: R-40297-14464 The INDEXED BY phrase forces the SQLite
# query planner to use a particular named index on a DELETE, SELECT, or
# UPDATE statement.
#
# Test that "INDEXED BY" can be used in a DELETE statement.
# 
do_execsql_test indexedby-7.1 {
  EXPLAIN QUERY PLAN DELETE FROM t1 WHERE a = 5 
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_3_i1 (a=?)}}
do_execsql_test indexedby-7.2 {
  EXPLAIN QUERY PLAN DELETE FROM t1 NOT INDEXED WHERE a = 5 
} {0 0 0 {SCAN TABLE t1}}
do_execsql_test indexedby-7.3 {
  EXPLAIN QUERY PLAN DELETE FROM t1 INDEXED BY '517_3_i1' WHERE a = 5 
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_3_i1 (a=?)}}
do_execsql_test indexedby-7.4 {
  EXPLAIN QUERY PLAN DELETE FROM t1 INDEXED BY '517_3_i1' WHERE a = 5 AND b = 10
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_3_i1 (a=?)}}
do_execsql_test indexedby-7.5 {
  EXPLAIN QUERY PLAN DELETE FROM t1 INDEXED BY '517_2_i2' WHERE a = 5 AND b = 10
} {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX 517_2_i2 (b=?)}}

# MUST_WORK_TEST

# do_test indexedby-7.6 {
#   catchsql { DELETE FROM t1 INDEXED BY '517_2_i2' WHERE a = 5}
# } {1 {no query solution}}

# # Test that "INDEXED BY" can be used in an UPDATE statement.
# # 
# do_execsql_test indexedby-8.1 {
#   EXPLAIN QUERY PLAN UPDATE t1 SET rowid=rowid+1 WHERE a = 5 
# } {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX i1 (a=?)}}
# do_execsql_test indexedby-8.2 {
#   EXPLAIN QUERY PLAN UPDATE t1 NOT INDEXED SET rowid=rowid+1 WHERE a = 5 
# } {0 0 0 {SCAN TABLE t1}}
# do_execsql_test indexedby-8.3 {
#   EXPLAIN QUERY PLAN UPDATE t1 INDEXED BY i1 SET rowid=rowid+1 WHERE a = 5 
# } {0 0 0 {SEARCH TABLE t1 USING COVERING INDEX i1 (a=?)}}
# do_execsql_test indexedby-8.4 {
#   EXPLAIN QUERY PLAN 
#   UPDATE t1 INDEXED BY i1 SET rowid=rowid+1 WHERE a = 5 AND b = 10
# } {0 0 0 {SEARCH TABLE t1 USING INDEX i1 (a=?)}}
# do_execsql_test indexedby-8.5 {
#   EXPLAIN QUERY PLAN 
#   UPDATE t1 INDEXED BY i2 SET rowid=rowid+1 WHERE a = 5 AND b = 10
# } {0 0 0 {SEARCH TABLE t1 USING INDEX i2 (b=?)}}
# do_test indexedby-8.6 {
#   catchsql { UPDATE t1 INDEXED BY i2 SET rowid=rowid+1 WHERE a = 5}
# } {1 {no query solution}}

# Test that bug #3560 is fixed.
#
do_test indexedby-9.1 {
  execsql {
    CREATE TABLE maintable( id integer PRIMARY KEY );
    CREATE TABLE joinme(id_int integer PRIMARY KEY, id_text text);
    CREATE INDEX joinme_id_text_idx on joinme(id_text);
    CREATE INDEX joinme_id_int_idx on joinme(id_int);
  }
} {}

# MUST_WORK_TEST

# do_test indexedby-9.2 {
#   catchsql {
#     select * from maintable as m inner join
#     joinme as j indexed by '547_1_joinme_id_text_idx'
#     on ( m.id  = j.id_int)
#   }
# } {1 {no query solution}}
# do_test indexedby-9.3 {
#   catchsql { select * from maintable, joinme INDEXED by '547_1_joinme_id_text_idx' }
# } {1 {no query solution}}

# Make sure we can still create tables, indices, and columns whose name
# is "indexed".
#
do_test indexedby-10.1 {
  execsql {
    CREATE TABLE indexed(x PRIMARY KEY,y);
    INSERT INTO indexed VALUES(1,2);
    SELECT * FROM indexed;
  }
} {1 2}
do_test indexedby-10.2 {
  execsql {
    CREATE INDEX i10 ON indexed(x);
    SELECT * FROM indexed indexed by '552_1_i10' where x>0;
  }
} {1 2}
do_test indexedby-10.3 {
  execsql {
    DROP TABLE indexed;
    CREATE TABLE t10(indexed INTEGER PRIMARY KEY);
    INSERT INTO t10 VALUES(1);
    CREATE INDEX indexed ON t10(indexed);
    SELECT * FROM t10 indexed by '552_1_indexed' WHERE indexed>0
  }
} {1}

# #-------------------------------------------------------------------------
# # Ensure that the rowid at the end of each index entry may be used
# # for equality constraints in the same way as other indexed fields.
# #
# do_execsql_test 11.1 {
#   CREATE TABLE x1(a, b TEXT);
#   CREATE INDEX x1i ON x1(a, b);
#   INSERT INTO x1 VALUES(1, 1);
#   INSERT INTO x1 VALUES(1, 1);
#   INSERT INTO x1 VALUES(1, 1);
#   INSERT INTO x1 VALUES(1, 1);
# }
# do_execsql_test 11.2 {
#   SELECT a,b,rowid FROM x1 INDEXED BY x1i WHERE a=1 AND b=1 AND rowid=3;
# } {1 1 3}
# do_execsql_test 11.3 {
#   SELECT a,b,rowid FROM x1 INDEXED BY x1i WHERE a=1 AND b=1 AND rowid='3';
# } {1 1 3}
# do_execsql_test 11.4 {
#   SELECT a,b,rowid FROM x1 INDEXED BY x1i WHERE a=1 AND b=1 AND rowid='3.0';
# } {1 1 3}
# do_eqp_test 11.5 {
#   SELECT a,b,rowid FROM x1 INDEXED BY x1i WHERE a=1 AND b=1 AND rowid='3.0';
# } {0 0 0 {SEARCH TABLE x1 USING COVERING INDEX x1i (a=? AND b=? AND rowid=?)}}

# do_execsql_test 11.6 {
#   CREATE TABLE x2(c INTEGER PRIMARY KEY, a, b TEXT);
#   CREATE INDEX x2i ON x2(a, b);
#   INSERT INTO x2 VALUES(1, 1, 1);
#   INSERT INTO x2 VALUES(2, 1, 1);
#   INSERT INTO x2 VALUES(3, 1, 1);
#   INSERT INTO x2 VALUES(4, 1, 1);
# }
# do_execsql_test 11.7 {
#   SELECT a,b,c FROM x2 INDEXED BY x2i WHERE a=1 AND b=1 AND c=3;
# } {1 1 3}
# do_execsql_test 11.8 {
#   SELECT a,b,c FROM x2 INDEXED BY x2i WHERE a=1 AND b=1 AND c='3';
# } {1 1 3}
# do_execsql_test 11.9 {
#   SELECT a,b,c FROM x2 INDEXED BY x2i WHERE a=1 AND b=1 AND c='3.0';
# } {1 1 3}
# do_eqp_test 11.10 {
#   SELECT a,b,c FROM x2 INDEXED BY x2i WHERE a=1 AND b=1 AND c='3.0';
# } {0 0 0 {SEARCH TABLE x2 USING COVERING INDEX x2i (a=? AND b=? AND rowid=?)}}

finish_test