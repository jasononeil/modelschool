package modelschool.core.model;

import ufront.db.Object;
import sys.db.Types;
import modelschool.core.model.*;

class Home extends Object
{
	public var dbKey:Null<SString<20>>;
	public var location:Null<BelongsTo<Location>>;
	public var phone:Null<SString<20>>;
	public var fax:Null<SString<20>>;
}
