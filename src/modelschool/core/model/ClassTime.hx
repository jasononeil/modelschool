package modelschool.core.model;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;
import thx.culture.Culture;
import modelschool.core.model.*;
using CleverSort;
using thx.format.Format;
using Lambda;

class ClassTime extends Object
{
	public var day:STinyUInt;
	public var occurrence:STinyInt;
	public var linkedToNextPeriod:Bool = false;
	
	public var teacher:BelongsTo<StaffMember>;
	public var teacherAids:ManyToMany<ClassTime,StaffMember>;
	public var room:BelongsTo<Room>;
	public var period:BelongsTo<Period>;
	public var schoolClass:BelongsTo<SchoolClass>;

	@:skip 	public var dayName(get,null):String;

	function get_dayName()
	{
		return Culture.invariant.dateTime.nameDays[day];
	}

	public static function sortClassTimes(cts:Iterable<ClassTime>)
	{
		var sorted = cts.array();
		sorted.cleverSort( _.day, _.period.position );
		return sorted;
	}
	
	public override function toString()
	{
		return '$dayName, ${period.shortName}, $schoolClass';
	}
}