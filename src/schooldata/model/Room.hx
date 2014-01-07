package schooldata.model;

import sys.db.Types;
import ufront.db.Object;

import schooldata.model.*;

class Room extends Object
{
	public var name:SString<10>;
	public var description:Null<SString<50>>;
}