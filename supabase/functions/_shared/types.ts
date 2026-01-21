export interface Creator {
  id: string;
  display_name: string;
  fanvue_creator_id: string;
  settings_json: CreatorSettings;
  is_active: boolean;
  created_at: string;
  // updated_at: string;
}

export interface CreatorSettings {
  // Basic Info
  name?: string;
  age?: number;
  location?: string;
  occupation?: string;

  // Personality
  personality_traits?: string[];
  speaking_style?: string;
  hobbies?: string[];
  backstory?: string;

  // Boundaries
  do_rules?: string[];
  dont_rules?: string[];

  // Behavior Settings (1-10)
  flirtiness?: number;
  lewdness?: number;
  emoji_usage?: number;

  // AI Detection Handling
  ai_deflection_responses?: string[];

  // Legacy settings (still supported)
  arrogance?: number;
  dominance?: number;
  emoji_rate?: 'low' | 'mid' | 'high';
  reply_length?: 'short' | 'medium' | 'long';
  sales_aggression?: number;
  reply_delay_min?: number;
  reply_delay_max?: number;
  sleep_delay_min?: number;
  sleep_delay_max?: number;
  broadcast_enabled?: boolean;
  broadcast_threshold?: number;
  broadcast_cooldown?: number;
}

export interface Fan {
  id: string;
  fanvue_id: string;
  username: string;
  display_name: string;
  // Human-like behavior fields
  pacing_config?: PacingConfig;
  stage?: FanStage;
  msg_count_inbound?: number;
  total_spend?: number;
  tags?: string[];
}

export type FanStage = 'new' | 'warmup' | 'flirty' | 'sales' | 'post_purchase' | 'vip';

export interface PacingConfig {
  base_delay: number;      // Average seconds to wait (30-80)
  variance: number;        // Random +/- deviation
  long_pause_chance: number; // Chance of 5-min break (0-1)
}

export interface Job {
  id: string;
  creator_id: string;
  type: 'reply' | 'broadcast' | 'followup';
  payload: any;
  status: 'queued' | 'processing' | 'completed' | 'failed';
  attempts: number;
  last_error?: string;
  run_at: string;
  created_at: string;
}

export interface WebhookPayload {
  event: string; // e.g., 'message.created'
  data: any;
  timestamp: string;
}

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
