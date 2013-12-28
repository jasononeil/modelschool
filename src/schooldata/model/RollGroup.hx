package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;

import app.coredata.model.*;

class RollGroup extends Object
{
	public var name:SString<5>;
	public var description:SString<255>;
	public var yeargroup:STinyInt;
	public var yeargroup2:Null<STinyInt>;
	
	public var teacher:Null<BelongsTo<StaffMember>>;
	public var students:HasMany<Student>;

	@:skip public var yeargroupStr(get,never):String;
	function get_yeargroupStr()
	{
		return (yeargroup2 != null) ? '$yeargroup/$yeargroup2' : '$yeargroup';
	}
}