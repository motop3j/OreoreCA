create table selfsignedcertificates (
	id integer primary key autoincrement,
	subject text,
	notbefore datetime,
	notafter datetime,
	privatekey text,
	digest text,
	certificate text,
	created datetime
);

