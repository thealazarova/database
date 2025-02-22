@../imlogin.sql

set pages 9999
set lines 150

set timing on
set echo on

-- In-Memory query with In-Memory Aggregation disabled

SELECT /*+ NO_VECTOR_TRANSFORM */
          d.d_year, c.c_nation, sum(lo_revenue - lo_supplycost) profit
          From      LINEORDER l, DATE_DIM d, PART p, SUPPLIER s, CUSTOMER C
          Where    l.lo_orderdate = d.d_datekey
          And        l.lo_partkey       = p.p_partkey
          And        l.lo_suppkey      = s.s_suppkey
          And        l.lo_custkey        = c.c_custkey
          And        s.s_region            = 'AMERICA'
          And        c.c_region            = 'AMERICA'
          Group by d.d_year, c.c_nation
          Order by d.d_year, c.c_nation;

set echo off
set timing off

pause Hit enter ...

select * from table(dbms_xplan.display_cursor());

