package app.coredata.model;

import ufront.db.Object;
import sys.db.Types;
import app.coredata.model.*;

class Family extends Object
{
	public var mazeKey:SString<20>;

	public var motherName:SString<60>;
	public var motherMobile:SString<20>;
	public var motherWorkPhone:SString<20>;
	public var motherEmail:SString<60>;

	public var fatherName:SString<60>;
	public var fatherMobile:SString<20>;
	public var fatherWorkPhone:SString<20>;
	public var fatherEmail:SString<60>;

	public var homeTitle:Null<SString<100>>;
	public var homeAddress:Null<BelongsTo<Home>>;

	public var mailTitle:Null<SString<100>>;
	public var mailAddress:Null<BelongsTo<Home>>;
	
	public var billingTitle:Null<Null<SString<100>>>;
	public var billingAddress:Null<BelongsTo<Home>>;

	public var children:HasMany<Student>;
}