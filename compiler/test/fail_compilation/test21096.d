// https://issues.dlang.org/show_bug.cgi?id=21096

/*
TEST_OUTPUT:
---
fail_compilation/test21096.d(11): Error: identifier or new keyword expected following `(...)`.
fail_compilation/test21096.d(11): Error: variable name expected after type `char[(__error)]`, not `;`
---
*/

char[(void*).];
