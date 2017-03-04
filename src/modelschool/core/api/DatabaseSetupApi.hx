package modelschool.core.api;

import sys.db.TableCreate;
import sys.db.Manager;
import ufront.MVC;
import ufront.ORM;
import ufront.EasyAuth;
import modelschool.CoreApi;

class DatabaseSetupApi {
	public function new() {}

	public function setupDatabase():Void {
		var tables:Array<Manager<Dynamic>> = [
			// Ufront
			User.manager,
			Group.manager,
			Permission.manager,
			// Modelschool
			ClassListHistory.manager,
			TimetableSet.manager,
			StudentEnrolmentHistory.manager,
			TeacherEnrolmentHistory.manager,
			ClassTime.manager,
			Department.manager,
			District.manager,
			Family.manager,
			Home.manager,
			Location.manager,
			Parent.manager,
			Period.manager,
			Person.manager,
			RollGroup.manager,
			Room.manager,
			School.manager,
			SchoolClass.manager,
			SchoolHouse.manager,
			StaffMember.manager,
			StaffMemberProfile.manager,
			Student.manager,
			StudentPhoto.manager,
			StudentProfile.manager,
			Subject.manager,
		];
		for (t in tables) {
			createTableIfNecessary(t);
		}
		ManyToMany.createJoinTable(User, Group);
		ManyToMany.createJoinTable(TimetableSet, Period);
		ManyToMany.createJoinTable(ClassTime, StaffMember);
		ManyToMany.createJoinTable(Department, StaffMember);
		ManyToMany.createJoinTable(Family, Student);
		ManyToMany.createJoinTable(Family, Parent);
		ManyToMany.createJoinTable(School, Student);
		ManyToMany.createJoinTable(School, StaffMember);
		ManyToMany.createJoinTable(SchoolClass, Student);
		ManyToMany.createJoinTable(StaffMember, ClassTime);
	}

	function createTableIfNecessary(manager:Manager<Dynamic>):Void {
		if (!TableCreate.exists(manager)) {
			TableCreate.create(manager);
		}
	}
}
