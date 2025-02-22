# Operational Property Graphs Example with SQL/PGQ in 23c

## Introduction


In this lab you will query the newly created graph (that is, `bank_graph`) using SQL/PGQ a new extension in SQL:2023.
​
Estimated Time: 30 minutes.
​
Watch the video below for a quick walk through of the lab.
​
<!-- update video link. Previous iteration: [](youtube:XnE1yw2k5IU) -->
​
### Objectives
Learn how to:
- Use APEX and SQL/PGQ to define and query a property graph.
​
### Prerequisites
This lab assumes:  
- The database user exists and has the right roles and privileges.
- The bank\_accounts and bank\_transfers tables exist. 
​
### Tables are  

| Name | Null? | Type |
| ------- |:--------:| --------------:|
| ID | NOT NULL | NUMBER|
| NAME |  | VARCHAR2(4000) |
| BALANCE |  | NUMBER |
{: title="BANK_ACCOUNTS"}

| Name | Null? | Type |
| ------- |:--------:| --------------:|
| TXN_ID | NOT NULL | NUMBER|
| SRC\_ACCT\_ID |  | NUMBER |
| DST\_ACCT\_ID |  | NUMBER |
| DESCRIPTION |  | VARCHAR2(4000) |
| AMOUNT |  | NUMBER |
{: title="BANK_TRANSFERS"}
​
## Task 1 : Define a graph view on these tables
1. Stay in your SQL command window and click Clear Command after every time you execute a command. 
​     ![SQL command window](images/clear-command311.png " ")
​
2. Use the following SQL statement to create a property graph called BANK\_GRAPH using the BANK\_ACCOUNTS table as the vertices and the BANK_TRANSFERS table as edges. 
    
    ```
    <copy>
    CREATE PROPERTY GRAPH BANK_GRAPH 
    VERTEX TABLES (
        BANK_ACCOUNTS
        KEY (ID)
        PROPERTIES (ID, Name, Balance) 
    )
    EDGE TABLES (
        BANK_TRANSFERS 
        KEY (TXN_ID) 
        SOURCE KEY (src_acct_id) REFERENCES BANK_ACCOUNTS(ID)
        DESTINATION KEY (dst_acct_id) REFERENCES BANK_ACCOUNTS(ID)
        PROPERTIES (src_acct_id, dst_acct_id, amount)
    );
    </copy>
    ```
​
    <!-- REPLACE IMAGE ![Create graph using Accounts and Transfers table](images/create-graph.png) -->

    ![need image](images/example.png)
​
​
3. You can check the metadata views to list the graph, its elements, their labels, and their properties. 
​
    First we will be listing the graphs, but there is only one property graph we have created, so BANK\_GRAPH will be the only entry.
    
    ```
    <copy>
    SELECT * FROM user_property_graphs;
    </copy>
    ```
​     ![Check metadata views](images/metadata313.png " ")
​
4. This query shows the DDL for the BANK_GRAPH graph. 
​
    ```
    <copy>
    SELECT dbms_metadata.get_ddl('PROPERTY_GRAPH', 'BANK_GRAPH') from dual;
    </copy>
    ```
    
    ![DDL for bank graph](images/ddl-bankgraph314.png " ") 


5. Here you can look at the elements of the BANK\_GRAPH graph (i.e. its vertices and edges).
    
    ```
    <copy>
    SELECT * FROM user_pg_elements WHERE graph_name='BANK_GRAPH';
    </copy>
    ```

 ​    ![Elements of bank graph](images/elements-bankgraph315.png " ")
​
6. Get the properties associated with the labels.
    
    ```
    <copy>
    SELECT * FROM user_pg_label_properties WHERE graph_name='BANK_GRAPH';
    </copy>
    ```
​
​     ![Properties associated with labels](images/properties316.png " ")

​
​
## Task 2 : Query the bank_graph
​
In this task we will run queries using SQL/PGQ's GRAPH_TABLE operator, MATCH clause, and COLUMNS clause. The GRAPH\_TABLE operator enables you to query the property graph by specifying a graph pattern to look for and return the results as a set of columns. The MATCH clause lets you specify the graph patterns, and the COLUMN clause lists the query output columns. Everything else is existing SQL syntax.
​
A common query in analyzing money flows is to see if there are a sequence of transfers that connect one source account to a destination account. We'll be demonstrating that sequence of transfers in standard SQL.
​
1. Let's start by finding the top 10 accounts which have the most incoming transfers. 
    
    ```
    <copy>
    SELECT acct_id, COUNT(1) AS Num_Transfers 
    FROM graph_table ( BANK_GRAPH 
        MATCH (src) - [IS BANK_TRANSFERS] -> (dst) 
        COLUMNS ( dst.id AS acct_id )
    ) GROUP BY acct_id ORDER BY Num_Transfers DESC FETCH FIRST 10 ROWS ONLY;
    </copy>
    ```
​     ![top 10 accounts](images/topten-accounts321.png " ")
​
    We see that accounts **934** and **387** are high on the list. 
    
2.  What if we want to find the accounts where money was simply passing through. That is, let's find the top 10 accounts in the middle of a 2-hop chain of transfers.
    
    ```
    <copy>
    SELECT acct_id, COUNT(1) AS Num_In_Middle 
    FROM graph_table ( BANK_GRAPH 
        MATCH (src) - [IS BANK_TRANSFERS] -> (via) - [IS BANK_TRANSFERS] -> (dst) 
        COLUMNS ( via.id AS acct_id )
    ) GROUP BY acct_id ORDER BY Num_In_Middle DESC FETCH FIRST 10 ROWS ONLY;
    </copy>
    ```
​     ![Money passing through accounts](images/money-passing-through322.png " ")
​
3. Note that account 387 shows up in both, so let's list accounts that received a transfer from account 387 in 1, 2, or 3 hops.
    
    ```
    <copy>
    SELECT account_id1, account_id2 
    FROM graph_table(BANK_GRAPH
        MATCH (v1)-[IS BANK_TRANSFERS]->{1,3}(v2) 
        WHERE v1.id = 387 
        COLUMNS (v1.id AS account_id1, v2.id AS account_id2)
    );
    </copy>
    ```
​     ![shows in both](images/shows-in-both323.png " ")
​
4. We looked at accounts with the most incoming transfers and those which were simply conduits. Now let's query the graph to determine if there are any circular payment chains, i.e. a sequence of transfers that start and end at the saem account. First let's check if there are any 3-hop (triangles) transfers that start and end at the same account.
    
    ```
    <copy>
    SELECT acct_id, COUNT(1) AS Num_Triangles 
    FROM graph_table (BANK_GRAPH 
        MATCH (src) - []->{3} (src) 
        COLUMNS (src.id AS acct_id) 
    ) GROUP BY acct_id ORDER BY Num_Triangles DESC;
    </copy>
    ```
​     ![most incoming transfer accounts](images/numtriangles324.png " ")
​
5. We can use the same query but modify the number of hops to check if there are any 4-hop transfers that start and end at the same account. 

    ```
    <copy>
    SELECT acct_id, COUNT(1) AS Num_4hop_Chains 
    FROM graph_table (BANK_GRAPH 
        MATCH (src) - []->{4} (src) 
        COLUMNS (src.id AS acct_id) 
    ) GROUP BY acct_id ORDER BY Num_4hop_Chains DESC;
    </copy>
    ```
​
​     ![Same query](images/same-query325.png " ")
​
6. Lastly, check if there are any 5-hop transfers that start and end at the same account by just changing the number of hops to 5. 
   
    ```
    <copy>
   SELECT acct_id, COUNT(1) AS Num_5hop_Chains 
    FROM graph_table (BANK_GRAPH 
        MATCH (src) - []->{5} (src) 
        COLUMNS (src.id AS acct_id) 
    ) GROUP BY acct_id ORDER BY Num_5hop_Chains DESC;
    </copy>
    ```  
    Note that though we are looking for longer chains we reuse the same MATCH pattern with a modified parameter for the desired number of hops. This compactness and expressiveness is a primary benefit of the new SQL/PGQ functionality.
    
​     ![5 hop transfers](images/five-hop-transfer326.png " ")

7.  Now that we know there are 3, 4, and 5-hop cycles let's list some (any 10) accounts that had these circular payment chains. 
   
    ```
    <copy>
    SELECT DISTINCT(account_id) 
    FROM GRAPH_TABLE(BANK_GRAPH
       MATCH (v1)-[IS BANK_TRANSFERS]->{3,5}(v1)
        COLUMNS (v1.id AS account_id)  
    ) FETCH FIRST 10 ROWS ONLY;
    </copy>
    ```
​
 ​     ![circular payment chains](images/circular-payment-chain327.png " ")
​
8.  Let's list the top 10 accounts by number of 3 to 5 hops that have circular payment chains in descending order. 
   
    ```
    <copy>
    SELECT DISTINCT(account_id), COUNT(1) AS Num_Cycles 
    FROM graph_table(BANK_GRAPH
        MATCH (v1)-[IS BANK_TRANSFERS]->{3, 5}(v1) 
        COLUMNS (v1.id AS account_id) 
    ) GROUP BY account_id ORDER BY Num_Cycles DESC FETCH FIRST 10 ROWS ONLY;
    </copy>
    ```
​
 ​     ![circular payment chains in descending order](images/descending-order328.png " ")
​
    Note that accounts **135**, **934** and **387** are the ones involved in most of the 3 to 5 hops circular payment chains. 
​
9. When we created the `BANK_GRAPH` property graph we essentially created a view on the underlying tables and metadata. No data is duplicated. So any insert, update, or delete on the underlying tables will also be reflected in the property graph.   
​
Now, let's insert some more data into BANK\_TRANSFERS. We will see that when rows are inserted in to the BANK\_TRANSFERS table, the BANK\_GRAPH is updated with corresponding edges.
   
    ```
    <copy>
    begin
    INSERT INTO bank_transfers VALUES (5002, 39, 934, null, 1000);
    INSERT INTO bank_transfers VALUES (5003, 39, 135, null, 1000);
    INSERT INTO bank_transfers VALUES (5004, 40, 135, null, 1000);
    INSERT INTO bank_transfers VALUES (5005, 41, 135, null, 1000);
    INSERT INTO bank_transfers VALUES (5006, 38, 135, null, 1000);
    INSERT INTO bank_transfers VALUES (5007, 37, 135, null, 1000);
    end;
    </copy>
    ```
   ​     ![insert more data into bank transfers](images/beginend329.png " ")


10.   Re-run the top 10 query to see if there are any changes after inserting rows in BANK\_TRANSFERS.
   
    ```
    <copy>
    SELECT acct_id, count(1) AS Num_Transfers 
    FROM GRAPH_TABLE ( bank_graph 
    MATCH (src) - [is BANK_TRANSFERS] -> (dst) 
    COLUMNS ( dst.id as acct_id )
    ) GROUP BY acct_id ORDER BY Num_Transfers DESC fetch first 10 rows only;
    </copy>
    ```
   ​     ![rerun top 10 query](images/rerun3210.png " ")
​
    Notice how accounts **135**, and **934** are now ahead of **387**.
​
11. In Step 5 above we saw that accounts 135 and 934 had a number of 4-hop circular payments chains. Let's check if account 39 had any.
    
    ```
    <copy>
    SELECT count(1) Num_4Hop_Cycles 
    FROM graph_table(bank_graph 
    MATCH (s)-[]->{4}(s) 
    WHERE s.id = 39
    COLUMNS (1 as dummy) );
    </copy>
    ```
   ​     ![account 39](images/accountthirtynine3211.png " ")
​
    It has 2.      
​
12.  So let's insert more transfers which create 3 more circular payment chains. We will be adding transfers from accounts **599**, **982**, and **407** into account **39**.
   
    ```
    <copy>
    begin
    INSERT INTO bank_transfers VALUES (5008, 559, 39, null, 1000);
    INSERT INTO bank_transfers VALUES (5009, 982, 39, null, 1000);
    INSERT INTO bank_transfers VALUES (5010, 407, 39, null, 1000);
    end;
    </copy>
    ```
  ​     ![inserting more transfers](images/begin-again3212.png " ")
​
13.  Re-run the following query since we've added more circular payment chains.
   
    ```
    <copy>
    SELECT count(1) Num_4Hop_Cycles 
    FROM graph_table(bank_graph 
    MATCH (s)-[]->{4}(s) 
    WHERE s.id = 39
    COLUMNS (1 as dummy) );
    </copy>
    ```
  ​     ![rerun query again](images/rerun-again3213.png " ")
​
    Notice how we now have five 4-hop circular payment chains because the edges of BANK\_GRAPH were updated when additional transfers were added to BANK\_TRANSFERS. 
​
14.  Finally let's undo the changes and delete the new inserted rows.
   
    ```
    <copy>
    DELETE FROM bank_transfers 
    WHERE txn_id IN (5002, 5003, 5004, 5005, 5006, 5007, 5008, 5009, 5010);
    </copy>
    ```

      ​ ![undo changes and delete rows](images/deleted-rows3214.png " ")

15. You have now completed this lab.

## Learn More
* [Oracle Property Graph](https://docs.oracle.com/en/database/oracle/property-graph/index.html)
* [SQL Property Graph syntax in Oracle Database 23c Free - Developer Release](https://docs.oracle.com/en/database/oracle/property-graph/23.1/spgdg/sql-ddl-statements-property-graphs.html#GUID-6EEB2B99-C84E-449E-92DE-89A5BBB5C96E)

## Acknowledgements

- **Author** - Kaylien Phan, Thea Lazarova, William Masdon
- **Contributors** - Melliyal Annamalai, Jayant Sharma, Ramu Murakami Gutierrez, Rahul Tasker
- **Last Updated By/Date** - Kaylien Phan, Thea Lazarova
