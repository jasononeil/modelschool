package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import modelschool.core.model.*;

class StudentProfile extends Object
{
	public var student:BelongsTo<Student>;
	public var password:Null<SString<255>>;

	public var placeOfBirth:SString<255>;
	public var countryOfBirth:SString<255>;
	public var residentStatus:SString<255>;
	public var nationality:SString<255>;
	public var indigenousStatus:SString<255>;
	public var languageAtHome:SString<255>;

	public var dateOfEntry:Null<SDate>;
	public var dateOfExit:Null<SDate>;
	public var yeargroupOfEntry:SString<255>;
	public var idCardExpiry:Null<SDate>;
	public var boarder:Bool;
	public var examNumber:Null<Int>;
	public var previousSchool:SString<255>;

	public var doctor:SString<255>;
	public var emergencyContacts:SData<Array<Contact>>;
	public var medicalCondition1:SString<255>;
	public var medicalCondition2:SString<255>;
	public var disability:Bool;
	public var medicalAlert:Bool;
	public var medicalNotes:SText;
	public var accessAlert:Bool;
	public var accessType:SNull<SString<255>>;
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