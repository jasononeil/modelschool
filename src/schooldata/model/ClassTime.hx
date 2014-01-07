package schooldata.model;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;

import schooldata.model.*;
using thx.util.CleverSort;
using Dates;
using Lambda;

class ClassTime extends Object
{
	public var day:STinyUInt;
	public var occurence:STinyInt;
	public var linkedToNextPeriod:Bool = false;
	
	public var teacher:BelongsTo<StaffMember>;
	public var teacherAids:ManyToMany<ClassTime,StaffMember>;
	public var room:BelongsTo<Room>;
	public var period:BelongsTo<Period>;
	public var schoolClass:BelongsTo<SchoolClass>;

	@:skip 	public var dayName(get,null):String;

	function get_dayName()
	{
		return day.weekDayNameFromNum();
	}

	public static function sortClassTimes(cts:Iterable<ClassTime>)
	{
		var sorted = cts.array();
		sorted.cleverSort( _.day, _.period.position );
		return sorted;
	}
}