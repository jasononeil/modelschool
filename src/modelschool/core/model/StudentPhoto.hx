package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;

import modelschool.core.model.*;

class StudentPhoto extends Object
{
	public var photo:SBinary;
	public var hash:SString<32>;
	public var student:BelongsTo<Student>;
}