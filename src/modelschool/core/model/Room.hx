package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;

import modelschool.core.model.*;

class Room extends Object
{
	public var name:SString<10>;
	public var description:Null<SString<50>>;
	public var school:BelongsTo<School>;
}
