package modelschool.core.model;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;
import modelschool.core.model.*;

class Family extends Object
{
	public var dbKey:Null<SString<20>>;
	public var surname:SString<50>;

	public var children:ManyToMany<Family,Student>;
	public var parents:ManyToMany<Family,Parent>;

	public var notes:Null<SText>;

	public var homeTitle:Null<SString<100>>;
	public var homeAddress:Null<BelongsTo<Home>>;

	public var mailTitle:Null<SString<100>>;
	public var mailAddress:Null<BelongsTo<Home>>;
	
	public var billingTitle:Null<Null<SString<100>>>;
	public var billingAddress:Null<BelongsTo<Home>>;
}