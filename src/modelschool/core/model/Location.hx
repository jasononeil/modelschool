package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import modelschool.core.model.*;

class Location extends Object
{
	public var address:String;
	public var city:SString<255>;
	public var state:SString<255>;
	public var country:SString<255>;
	public var zip:SString<10>;
}
