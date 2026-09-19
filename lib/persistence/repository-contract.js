'use strict';

// Stable domain-facing persistence contract. The Flutter API and business
// engines depend on these capabilities, not on a specific hosting vendor.
const REQUIRED_METHODS = Object.freeze([
  'createUser', 'userByEmail', 'userByPhone', 'userById', 'touchLogin',
  'getState', 'setState', 'removeState', 'getSubscription',
  'setName', 'setEmail', 'setPhone', 'setVerified', 'setPassword', 'audit',
  'mobileProfile', 'saveMobileProfile', 'saveWorkoutPlan', 'activeWorkoutPlan',
  'startWorkoutSession', 'workoutSession', 'activeWorkoutSession',
  'saveWorkoutSet', 'workoutSets', 'finishWorkoutSession',
  'recentWorkoutSessions', 'exerciseHistory',
  'saveNutritionDay', 'nutritionDay', 'nutritionHistory',
  'saveWeight', 'recentWeights', 'saveMeasurement', 'recentMeasurements',
  'foodPreferences', 'markFoodUsed', 'setFoodFavorite',
  'weightsPage', 'measurementsPage', 'nutritionPage', 'workoutSessionsPage',
  'getFeatureFlag', 'setFeatureFlag', 'getAllFeatureFlags',
]);

function verifyRepositoryContract(repository) {
  const missing = REQUIRED_METHODS.filter((name) => typeof repository[name] !== 'function');
  if (missing.length) throw new Error('repository_contract_failed:' + missing.join(','));
  return Object.freeze({
    verified: true,
    version: 1,
    methodCount: REQUIRED_METHODS.length,
  });
}

module.exports = { REQUIRED_METHODS, verifyRepositoryContract };
