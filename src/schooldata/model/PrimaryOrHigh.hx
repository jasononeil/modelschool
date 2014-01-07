package schooldata.model;
using Lambda;

enum PrimaryOrHigh {
	Primary;
	Secondary;
}

class PrimaryOrHighTools {
	public static function getYeargroups( v:PrimaryOrHigh ) {
		return switch v {
			case Primary: AppConfig.primaryYears();
			case Secondary: AppConfig.secondaryYears();
		}
	}
	public static function primaryOrHighFromYeargroups( y:Int ) {
		if ( AppConfig.primaryYears().has(y) ) return Primary;
		if ( AppConfig.secondaryYears().has(y) ) return Secondary;
		return null;
	}
}