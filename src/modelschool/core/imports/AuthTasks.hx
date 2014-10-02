package modelschool.core.imports;
using StringTools;

// import ufront.auth.model.*;
// import modelschool.core.model.*;
// import modelschool.core.model.Person;
// import AppPermissions;
import ufront.tasks.TaskSet;
// import ufront.ufadmin.UFAdminPermissions;

class AuthTasks extends TaskSet
{
	// @help("Set up groups and permissions for SMS")
	// public function doSetupsmsgroups()
	// {
	// 	Permission.manager.delete(true);

	// 	// Permissions for all users
	// 	var users = createOrGetGroup("users").group;

	// 	// Permissions for all staff
	// 	var staff = createOrGetGroup("staff").group;
		
	// 	// Permissions for teachers
	// 	var teachers = createOrGetGroup("teachers").group;
	// 	Permission.addPermission(staff, AppPermissions.AccessStaffArea);

	// 	// Permissions for HODs
	// 	var hods = createOrGetGroup("hods").group;

	// 	// Permissions for HODs
	// 	var hoys = createOrGetGroup("hoys").group;
	// 	Permission.addPermission(hoys, AppPermissions.AccessAdminFeatures);
	// 	Permission.addPermission(hoys, AppPermissions.ViewBehaviourReports);

	// 	// Permissions for HODs
	// 	var deputies = createOrGetGroup("deputies").group;
	// 	Permission.addPermission(deputies, AppPermissions.AccessAdminFeatures);
	// 	Permission.addPermission(deputies, AppPermissions.ViewBehaviourReports);

	// 	// Permissions for nonTeachingStaff
	// 	var nonTeachingStaff = createOrGetGroup("nonTeachingStaff").group;

	// 	// Permissions for nonTeachingStaff
	// 	var admin = createOrGetGroup("admin").group;
	// 	Permission.addPermission(admin, AppPermissions.AccessAdminFeatures);

	// 	// Permissions for students
	// 	var students = createOrGetGroup("students").group;

	// 	// Permissions for students
	// 	var superusers = createOrGetGroup("superusers").group;
	// 	Permission.addPermission(superusers, UFAdminPermissions.CanAccessAdminArea);
	// 	Permission.addPermission(superusers, UFAdminPermissions.CanRunMigrations);
	// 	Permission.addPermission(superusers, UFAdminPermissions.CanRunAdminTasks);
	// 	Permission.addPermission(superusers, AppPermissions.EmulateOtherUser);
	// }

	// @help("Create a staff member")
	// public function doCreateuser(username:String, password:String, firstName:String, lastName:String) 
	// {
	// 	trace ("Check the user doesn't already exist");
	// 	var existingUser = User.manager.select($username == username);

	// 	if (existingUser != null)
	// 	{
	// 		doAddusertogroup(username, "staff");
	// 		return ("User already exists, with ID " + existingUser.id);
	// 	}
	// 	else 
	// 	{
	// 		trace ("Create the user");
	// 		var u = new User(username, password);
	// 		u.insert();

	// 		trace ("Create the person");
	// 		var p = new Person();
	// 		p.firstName = firstName;
	// 		p.surname = lastName;
	// 		p.birthday = Date.now();
	// 		p.user = u;
	// 		p.gender = Male;
	// 		p.save();

	// 		trace ("Create the staff member");
	// 		var s = new StaffMember();
	// 		s.person = p;
	// 		s.title = "";
	// 		s.dbKey = "";
	// 		s.active = true;
	// 		s.save();

	// 		trace ("Create the staff profile");
	// 		var sP = new StaffMemberProfile();
	// 		sP.registration = "";
	// 		sP.wwcc = "";
	// 		sP.policeClearance = false;
	// 		sP.mobile = "";
	// 		sP.email = "";
	// 		sP.staffMember = s;
	// 		sP.save();

	// 		doAddusertogroup(username, "staff");
	// 		return ('Success: User $username created (ID=${u.id})');
	// 	}
	// }

	// @help("Change the password for an existing user. Set 'forceChange' to 'true' to require them to change it when they next log in.")
	// public function doChangepassword(username:String, newPassword:String, forceChange:String)
	// {
	// 	trace ("Find user:");
	// 	var user = User.manager.select($username == username);
	// 	if (user == null) return 'User not found: $username';
	// 	else trace('  Found user $username (${user.id})');

	// 	user.setPassword(newPassword);
	// 	user.forcePasswordChange = ("true" == forceChange);
	// 	user.save();
	// 	trace ('Using salt: ${user.salt}');
	// 	trace ('Using password: ${newPassword}');
	// 	trace ('       As hash: ${user.password}');
	// 	trace ('Force password change: ${user.forcePasswordChange}');

	// 	return 'Operation finished';
	// }

	// @help("Add user to a group")
	// public function doAddusertogroup(username:String, group:String) 
	// {
	// 	trace ("Find user:");
	// 	var user = User.manager.select($username == username);
	// 	if (user == null) return 'User not found: $username';
	// 	else trace('  Found user $username (${user.id})');

	// 	trace ("Find group:");
	// 	var group = Group.manager.select($name == group);
	// 	if (group == null) return 'Group not found: $group';
	// 	else trace('  Found group ${group.name} (${group.id})');

	// 	trace ("Add user to group");
	// 	user.groups.add(group);

	// 	return "It worked!";
	// }

	// @help("Create groups.  To add more than 1, separate with a comma")
	// public function doCreategroups(groups:String)
	// {
	// 	var successfullyAdded:Array<String> = [];
	// 	for (groupName in groups.split(','))
	// 	{
	// 		groupName = groupName.ltrim().rtrim();
	// 		trace ('Group: $groupName');
	// 		var result = createOrGetGroup(groupName);
	// 		if (result.wasNew) successfullyAdded.push(result.group.name);
	// 	}

	// 	if (successfullyAdded.length > 0)
	// 	{
	// 		var count = successfullyAdded.length;
	// 		return 'Successfully added these $count groups: ${successfullyAdded.join(",")}';
	// 	}
	// 	else 
	// 		return "No groups were added";
	// }

	// function createOrGetGroup(name:String):{ wasNew:Bool, group:Group }
	// {
	// 	trace ('  Checking if group exists:');

	// 	var existingGroup = Group.manager.select($name == name);

	// 	if (existingGroup != null)
	// 	{
	// 		var id = existingGroup.id;
	// 		trace ('    It does (with ID $id), so skip it...');
	// 		return { wasNew: false, group: existingGroup };
	// 	}
	// 	else 
	// 	{
	// 		trace ('    It does not, so create it...');
			
	// 		var group = new Group();
	// 		group.name = name;
	// 		group.save();
			
	// 		var id = group.id;
	// 		trace ('  Group created successfully.  (ID=$id)');

	// 		return { wasNew: true, group: group };
	// 	}
	// }
}