package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import modelschool.core.model.*;

class Location extends Object
{
	public var dbKey:SString<20>;
	public var address:Null<String>;
	public var city:Null<SString<255>>;
	public var state:Null<SString<255>>;
	public var country:Null<SString<255>>;
	public var zip:Null<SString<10>>;
}
