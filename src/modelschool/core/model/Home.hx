package modelschool.core.model;

import ufront.db.Object;
import sys.db.Types;
import modelschool.core.model.*;

class Home extends Object
{
	public var dbKey:String;
	public var address:BelongsTo<Location>;
	public var phone:SString<20>;
	public var fax:SString<20>;
}
