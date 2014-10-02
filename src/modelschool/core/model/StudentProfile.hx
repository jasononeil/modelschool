package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import modelschool.core.model.*;

class StudentProfile extends Object
{
	public var student:BelongsTo<Student>;
	public var password:Null<SString<50>>;

	public var placeOfBirth:SString<50>;
	public var countryOfBirth:SString<30>;
	public var residentStatus:SString<30>;
	public var nationality:SString<30>;
	public var indigenousStatus:SString<100>;
	public var languageAtHome:SString<30>;

	public var dateOfEntry:SDate;
	public var yeargroupOfEntry:SString<10>;
	public var idCardExpiry:Null<SDate>;
	public var boarder:Bool;
	public var examNumber:Null<Int>;
	public var previousSchool:SString<50>;

	public var doctor:SString<100>;
	public var emergencyContacts:SData<Array<Contact>>;
	public var medicalCondition1:SString<50>;
	public var medicalCondition2:SString<50>;
	public var disability:Bool;
	public var medicalAlert:Bool;
	public var medicalNotes:SText;
	public var accessAlert:Bool;
	public var accessType:SNull<SString<15>>;
	public var accessNotes:SNull<SText>;
}

typedef Contact = {
	name:String,
	phone:String
}

enum ResidentStatus {
	Citizen;
}

enum IndigenousStatus {
	Neither;
}