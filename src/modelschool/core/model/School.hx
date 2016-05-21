package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import modelschool.core.model.*;

class School extends Object
{
	public var name:SString<255>;
	public var lowGrade:STinyInt;
	public var highGrade:STinyInt;
	public var pricinpal:Null<BelongsTo<Person>>;
	public var district:Null<BelongsTo<District>>;
	public var location:Null<BelongsTo<Location>>;
	public var students:ManyToMany<School,Student>;
	public var staffMember:ManyToMany<School,StaffMember>;
}
