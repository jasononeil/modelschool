package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;

import modelschool.core.model.*;

class Department extends Object
{
	public var name:SString<255>;

	public var hod:BelongsTo<StaffMember>;
	public var subjects:HasMany<Subject>;
	public var staff:ManyToMany<Department, StaffMember>;
}