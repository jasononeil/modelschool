package schooldata.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;

import schooldata.model.*;

class SchoolHouse extends Object
{
	public var shortName:SString<5>;
	public var name:SString<50>;
	public var students:HasMany<Student>;
}