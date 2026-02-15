/// Shared models, enums, constants, and utilities for the Vehicle Tracker system.
library shared;

// Enums
export 'src/enums/vehicle_type.dart';
export 'src/enums/violation_type.dart';
export 'src/enums/sync_status.dart';
export 'src/enums/user_role.dart';
export 'src/enums/outcome_type.dart';

// Models
export 'src/models/park.dart';
export 'src/models/highway_segment.dart';
export 'src/models/checkpost.dart';
export 'src/models/user_profile.dart';
export 'src/models/vehicle_passage.dart';
export 'src/models/violation.dart';
export 'src/models/violation_outcome.dart';
export 'src/models/sync_queue_item.dart';

// Constants
export 'src/constants/app_constants.dart';
export 'src/constants/api_constants.dart';
export 'src/constants/sms_format.dart';
export 'src/constants/plate_regex.dart';

// Utils
export 'src/utils/plate_normalizer.dart';
export 'src/utils/speed_calculator.dart';
export 'src/utils/sms_encoder.dart';
export 'src/utils/sms_decoder.dart';
