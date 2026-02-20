import { getServiceClient } from "./client.ts";

/**
 * Deletes test data in FK order for the given plate numbers
 */
export async function cleanup(plateNumbers: string[]): Promise<void> {
  if (plateNumbers.length === 0) return;

  const serviceClient = getServiceClient();

  // 1. Delete violation_outcomes (FK to violations)
  try {
    const { data: violations } = await serviceClient
      .from("violations")
      .select("id")
      .in("plate_number", plateNumbers);

    if (violations && violations.length > 0) {
      const violationIds = violations.map((v) => v.id);
      await serviceClient
        .from("violation_outcomes")
        .delete()
        .in("violation_id", violationIds);
    }
  } catch (_error) {
    // Ignore errors if no rows
  }

  // 2. Delete violations
  try {
    await serviceClient
      .from("violations")
      .delete()
      .in("plate_number", plateNumbers);
  } catch (_error) {
    // Ignore errors if no rows
  }

  // 3. Delete proactive_overstay_alerts
  try {
    await serviceClient
      .from("proactive_overstay_alerts")
      .delete()
      .in("plate_number", plateNumbers);
  } catch (_error) {
    // Ignore errors if no rows
  }

  // 4. Delete vehicle_passages
  try {
    await serviceClient
      .from("vehicle_passages")
      .delete()
      .in("plate_number", plateNumbers);
  } catch (_error) {
    // Ignore errors if no rows
  }
}
