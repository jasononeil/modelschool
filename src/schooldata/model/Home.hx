package schooldata.model;

import ufront.db.Object;
import sys.db.Types;
import schooldata.model.*;

class Home extends Object
{
	public var dbKey:String;
	public var address:SString<255>;
	public var state:SString<10>;
	public var postcode:SString<5>;
	public var phone:SString<20>;
	public var fax:SString<20>;
}