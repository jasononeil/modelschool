package modelschool.core.model;

import ufront.db.Object;
import sys.db.Types;
import modelschool.core.model.*;

class Family extends Object
{
	public var dbKey:Null<SString<20>>;

	public var children:HasMany<Student>;
	public var parents:HasMany<Parent>;

	public var homeTitle:Null<SString<100>>;
	public var homeAddress:Null<BelongsTo<Home>>;

	public var mailTitle:Null<SString<100>>;
	public var mailAddress:Null<BelongsTo<Home>>;
	
	public var billingTitle:Null<Null<SString<100>>>;
	public var billingAddress:Null<BelongsTo<Home>>;
}