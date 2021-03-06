BEGIN;

-- 1. Isolate the records of interest
CREATE TEMPORARY TABLE evttype_eid AS
SELECT
  eid 
FROM 
  -- Isolate sample type and event type.
  (SELECT eid
   FROM 
     (sample_assignments_generic 
      INNER JOIN  
      event_labels_generic_augmented
      USING (eid))
   WHERE 
     sample_type=6 AND
     grouped_dss_evttype={0}) AS Q1

  INNER JOIN 

  -- Isolate non-sideband
  (SELECT eid
   FROM sideband_generic
   WHERE sideband=0) AS Q2

  USING (eid)

-- undersampling
WHERE random() < :undersample;
;

CREATE INDEX ON evttype_eid (eid);


-- 2. Join records with the features
CREATE TEMPORARY TABLE evttype_features AS
SELECT 
  eid,
  logit_logre_signal_score AS z1,
  logit_logre_dstartau_score AS z2
FROM 
  evttype_eid 
  INNER JOIN 
  candidate_optimized_events_scores_generic_t 
  USING (eid)
WHERE 
  logit_gbdt300_signal_score IS NOT NULL AND 
  logit_gbdt300_dstartau_score IS NOT NULL AND 
  logit_logre_signal_score IS NOT NULL AND 
  logit_logre_dstartau_score IS NOT NULL
;
  
CREATE INDEX ON evttype_features (eid);

-- 3. Join records with the weights and brf mode strings
CREATE TEMPORARY VIEW evttype_training_sample AS
SELECT 
  z1, 
  z2, 
  (lumi_weight * 
   cln_weight * llswb1_weight * 
   continuum_logre_density_weight * 
   continuum_logre_normalization_weight) AS w,
  b1_brf_mode,
  b2_brf_mode
FROM 
  evttype_features INNER JOIN event_weights_generic_augmented USING (eid)
;

\copy (SELECT * FROM evttype_training_sample) TO 'evttype{0}.aux.csv' WITH DELIMITER ' ';


COMMIT;

