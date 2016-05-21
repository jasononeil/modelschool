package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;

import modelschool.core.model.*;

class Subject extends Object
{
	public var name:String;
	public var yeargroup:Null<STinyInt>;
	public var yeargroup2:Null<STinyInt>;
	public var dbKey:String;

	public var school:BelongsTo<School>;
	public var department:Null<BelongsTo<Department>>;
	public var contactTeacher:Null<BelongsTo<StaffMember>>;
	public var classes:HasMany<SchoolClass>;

	@:skip public var yeargroupStr(get,never):String;
	function get_yeargroupStr()
	{
		return (yeargroup2 != null) ? '$yeargroup/$yeargroup2' : '$yeargroup';
	}
}
