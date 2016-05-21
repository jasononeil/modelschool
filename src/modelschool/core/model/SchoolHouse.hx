package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;

import modelschool.core.model.*;

class SchoolHouse extends Object
{
	public var shortName:SString<5>;
	public var name:SString<50>;
	public var students:HasMany<Student>;
	public var school:BelongsTo<School>;
}
