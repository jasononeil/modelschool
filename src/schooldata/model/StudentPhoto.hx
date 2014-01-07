package schooldata.model;

import sys.db.Types;
import ufront.db.Object;

import schooldata.model.*;

class StudentPhoto extends Object
{
	public var photo:SBinary;
	public var hash:SString<32>;
	public var student:BelongsTo<Student>;
}