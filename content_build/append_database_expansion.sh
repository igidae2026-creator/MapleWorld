#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

data_dir="$repo_root/data"
mkdir -p "$data_dir"

regions=(
  "starter_fields:Starter Fields:1:18:starter"
  "henesys_plains:Henesys Plains:6:28:grassland"
  "ellinia_forest:Ellinia Forest:18:42:forest"
  "perion_rocklands:Perion Rocklands:28:56:rockland"
  "sleepywood_depths:Sleepywood Depths:35:68:underground"
  "kerning_city_shadow:Kerning City Shadow:32:70:urban"
  "orbis_skyrealm:Orbis Skyrealm:48:82:skyrealm"
  "ludibrium_clockwork:Ludibrium Clockwork:55:92:clockwork"
  "elnath_snowfield:Elnath Snowfield:68:106:snowfield"
  "minar_mountain:Minar Mountain:78:118:mountain"
  "coastal_harbors:Coastal Harbors:22:60:coast"
  "ancient_hidden_domains:Ancient Hidden Domains:88:132:ancient"
)

families=(
  "small_field_creatures"
  "mushroom_family"
  "plant_family"
  "beast_family"
  "undead_family"
  "mechanical_family"
  "magic_spirit_family"
  "humanoid_bandits"
  "cold_region_family"
  "mountain_dragon_family"
  "aquatic_family"
  "event_hidden_family"
)

mob_prefixes=(sprout moss briar fang grave gear rune rogue frost drake tide dusk)
mob_suffixes=(runner stalker bloom mauler sentinel keeper watcher brute oracle hunter binder warden)
elements=(neutral earth poison fire dark metal holy shadow ice wind water arcane)
rarities=(common uncommon rare epic legendary)
npc_roles=(shopkeeper questgiver townfolk traveler guard scholar smith ferryman hidden_story)
dialogue_types=(greeting region_hint quest_offer quest_progress quest_complete lore boss_rumor shop warning)
weapon_jobs=(warrior mage thief archer pirate)
weapon_subtypes=(sword axe spear staff dagger bow knuckle claw wand cannon)
armor_subtypes=(hat overall glove shoe cape shield shoulder ring belt pendant earring face accessory)
consumable_subtypes=(potion tonic elixir scroll booster ration charm banner meal)
material_subtypes=(ore herb fabric fang shell circuit rune crystal catalyst plate)
quest_item_subtypes=(document seal emblem badge relic sigil token shard key clue report)
etc_loot_subtypes=(pelt spore bone feather branch fossil cog ember pearl fragment)

ensure_header() {
  local file="$1"
  local header="$2"
  if [ ! -f "$file" ]; then
    printf '%s\n' "$header" > "$file"
  fi
}

line_count_no_header() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo 0
  else
    local lines
    lines=$(wc -l < "$file")
    if [ "$lines" -le 1 ]; then
      echo 0
    else
      echo $((lines - 1))
    fi
  fi
}

count_existing_prefix() {
  local file="$1"
  local prefix="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return
  fi
  awk -F, -v prefix="$prefix" 'NR > 1 && index($1, prefix) == 1 { c++ } END { print c + 0 }' "$file"
}

max_numeric_id() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo 0
    return
  fi
  awk -F, 'NR > 1 && $1 ~ /^[0-9]+$/ { if ($1 + 0 > max) max = $1 + 0 } END { print max + 0 }' "$file"
}

nth_prefixed_id() {
  local file="$1"
  local prefix="$2"
  local index="$3"
  awk -F, -v prefix="$prefix" -v target="$index" '
    NR > 1 && index($1, prefix) == 1 {
      count++
      if (count == target) {
        print $1
        exit
      }
    }
  ' "$file"
}

nth_region_npc_id() {
  local region_id="$1"
  local index="$2"
  awk -F, -v region="$region_id" -v target="$index" '
    NR > 1 && $4 == region {
      count++
      if (count == target) {
        print $1
        exit
      }
    }
  ' "$data_dir/npcs.csv"
}

join_by_pipe() {
  local first="$1"
  shift
  local out="$first"
  local item
  for item in "$@"; do
    out="${out}|${item}"
  done
  printf '%s' "$out"
}

ensure_header "$data_dir/maps.csv" "id,name,region,theme,recommended_level_min,recommended_level_max,adjacent_maps,portals,spawn_groups,npcs,boss_possible,hidden"
ensure_header "$data_dir/npcs.csv" "id,name,role,region,map_name,x,y,shop_inventory,quest_pool,personality"
ensure_header "$data_dir/dialogues.csv" "id,npc_id,map_name,dialogue_type,reference,text,next_id"

maps_existing=$(line_count_no_header "$data_dir/maps.csv")
npcs_existing=$(line_count_no_header "$data_dir/npcs.csv")
dialogues_existing=$(line_count_no_header "$data_dir/dialogues.csv")

if [ "$maps_existing" -lt 1280 ]; then
  map_id=$(max_numeric_id "$data_dir/maps.csv")
  : > "$data_dir/.maps_append.tmp"
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    canonical_combat_1="${region_id}_combat_01"
    canonical_combat_2="${region_id}_combat_02"
    canonical_combat_3="${region_id}_combat_03"
    canonical_town_1="${region_id}_town_01"
    if [ "$region_id" = "henesys_plains" ]; then
      canonical_town_1="henesys_town"
      canonical_combat_1="henesys_hunting_ground"
    elif [ "$region_id" = "sleepywood_depths" ]; then
      canonical_combat_1="ant_tunnel_1"
    elif [ "$region_id" = "starter_fields" ]; then
      canonical_combat_1="forest_edge"
    elif [ "$region_id" = "perion_rocklands" ]; then
      canonical_combat_1="perion_rocky"
    fi
    for i in $(seq 1 13); do
      map_id=$((map_id + 1))
      map_name="${region_id}_town_$(printf '%02d' "$i")"
      [ "$i" -eq 1 ] && map_name="$canonical_town_1"
      prev_name="${region_id}_town_$(printf '%02d' "$((i > 1 ? i - 1 : 1))")"
      next_name="${region_id}_town_$(printf '%02d' "$((i < 13 ? i + 1 : 13))")"
      [ "$i" -eq 1 ] && prev_name="$map_name"
      [ "$i" -eq 13 ] && next_name="${canonical_combat_1}"
      adjacent=$(join_by_pipe "$prev_name" "$next_name" "${region_id}_combat_01")
      portals=$(join_by_pipe "gate_${i}" "route_${i}" "hub_${region_id}")
      spawn_groups="safe_path|gather_square|bulletin_lane"
      npcs=$(join_by_pipe "${region_id}_npc_$(( (i - 1) * 6 + 1 ))" "${region_id}_npc_$(( (i - 1) * 6 + 2 ))" "${region_id}_npc_$(( (i - 1) * 6 + 3 ))")
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$map_id" "$map_name" "$region_id" "town_${theme}" "$lvl_min" "$((lvl_min + 6))" \
        "$adjacent" "$portals" "$spawn_groups" "$npcs" "false" "false" >> "$data_dir/.maps_append.tmp"
    done
    for i in $(seq 1 75); do
      map_id=$((map_id + 1))
      map_name="${region_id}_combat_$(printf '%02d' "$i")"
      [ "$i" -eq 1 ] && map_name="$canonical_combat_1"
      [ "$i" -eq 2 ] && map_name="$canonical_combat_2"
      [ "$i" -eq 3 ] && map_name="$canonical_combat_3"
      prev_name="${region_id}_combat_$(printf '%02d' "$((i > 1 ? i - 1 : 1))")"
      next_name="${region_id}_combat_$(printf '%02d' "$((i < 75 ? i + 1 : 75))")"
      [ "$i" -eq 1 ] && prev_name="$canonical_town_1"
      [ "$i" -eq 75 ] && next_name="${region_id}_dungeon_01"
      adjacent=$(join_by_pipe "$prev_name" "$next_name" "${region_id}_town_13")
      portals=$(join_by_pipe "upper_lane_${i}" "lower_lane_${i}" "rope_${i}")
      spawn_groups=$(join_by_pipe "${region_id}_field_cluster_$(((i - 1) % 8 + 1))" "${region_id}_elite_cluster_$(((i - 1) % 6 + 1))" "${region_id}_rare_cluster_$(((i - 1) % 4 + 1))")
      npcs=$(join_by_pipe "${region_id}_npc_$(( ((i - 1) % 77) + 1 ))" "${region_id}_npc_$(( ((i + 12) % 77) + 1 ))")
      boss_possible="false"
      if [ $((i % 15)) -eq 0 ]; then boss_possible="true"; fi
      level_min=$((lvl_min + (i - 1) / 3))
      level_max=$((level_min + 8))
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$map_id" "$map_name" "$region_id" "combat_${theme}" "$level_min" "$level_max" \
        "$adjacent" "$portals" "$spawn_groups" "$npcs" "$boss_possible" "false" >> "$data_dir/.maps_append.tmp"
    done
    for i in $(seq 1 16); do
      map_id=$((map_id + 1))
      map_name="${region_id}_dungeon_$(printf '%02d' "$i")"
      prev_name="${region_id}_dungeon_$(printf '%02d' "$((i > 1 ? i - 1 : 1))")"
      next_name="${region_id}_dungeon_$(printf '%02d' "$((i < 16 ? i + 1 : 16))")"
      [ "$i" -eq 1 ] && prev_name="${region_id}_combat_75"
      [ "$i" -eq 16 ] && next_name="${region_id}_hidden_01"
      adjacent=$(join_by_pipe "$prev_name" "$next_name" "${region_id}_combat_70")
      portals=$(join_by_pipe "depth_${i}" "shaft_${i}" "seal_${i}")
      spawn_groups=$(join_by_pipe "${region_id}_dungeon_cluster_$(((i - 1) % 8 + 1))" "${region_id}_boss_cluster_$(((i - 1) % 5 + 1))" "${region_id}_treasure_cluster_$(((i - 1) % 4 + 1))")
      npcs=$(join_by_pipe "${region_id}_npc_$(( ((i + 20) % 77) + 1 ))" "${region_id}_npc_$(( ((i + 35) % 77) + 1 ))")
      level_min=$((lvl_min + 18 + i))
      level_max=$((level_min + 10))
      boss_possible="false"
      if [ "$i" -ge 12 ]; then boss_possible="true"; fi
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$map_id" "$map_name" "$region_id" "dungeon_${theme}" "$level_min" "$level_max" \
        "$adjacent" "$portals" "$spawn_groups" "$npcs" "$boss_possible" "false" >> "$data_dir/.maps_append.tmp"
    done
    for i in $(seq 1 3); do
      map_id=$((map_id + 1))
      map_name="${region_id}_hidden_$(printf '%02d' "$i")"
      prev_name="${region_id}_dungeon_16"
      next_name="${region_id}_combat_01"
      [ "$i" -gt 1 ] && prev_name="${region_id}_hidden_$(printf '%02d' "$((i - 1))")"
      [ "$i" -lt 3 ] && next_name="${region_id}_hidden_$(printf '%02d' "$((i + 1))")"
      adjacent=$(join_by_pipe "$prev_name" "$next_name" "${region_id}_town_01")
      portals=$(join_by_pipe "veil_${i}" "echo_${i}" "glyph_${i}")
      spawn_groups=$(join_by_pipe "${region_id}_hidden_cluster_$i" "${region_id}_rare_cluster_$i" "${region_id}_boss_cluster_$i")
      npcs=$(join_by_pipe "${region_id}_npc_$(( ((i + 50) % 77) + 1 ))" "${region_id}_npc_$(( ((i + 60) % 77) + 1 ))")
      level_min=$((lvl_max - 10 + i))
      level_max=$((lvl_max + 6 + i))
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$map_id" "$map_name" "$region_id" "hidden_${theme}" "$level_min" "$level_max" \
        "$adjacent" "$portals" "$spawn_groups" "$npcs" "true" "true" >> "$data_dir/.maps_append.tmp"
    done
  done
  cat "$data_dir/.maps_append.tmp" >> "$data_dir/maps.csv"
  rm -f "$data_dir/.maps_append.tmp"
fi

if [ "$npcs_existing" -lt 920 ]; then
  npc_id=$(max_numeric_id "$data_dir/npcs.csv")
  : > "$data_dir/.npcs_append.tmp"
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for i in $(seq 1 77); do
      npc_id=$((npc_id + 1))
      role="${npc_roles[$(((i - 1) % ${#npc_roles[@]}))]}"
      if [ "$i" -le 13 ]; then
        map_name="${region_id}_town_$(printf '%02d' "$i")"
        [ "$region_id" = "henesys_plains" ] && [ "$i" -eq 1 ] && map_name="henesys_town"
      elif [ "$i" -le 58 ]; then
        map_name="${region_id}_combat_$(printf '%02d' "$((i - 13))")"
        [ "$region_id" = "henesys_plains" ] && [ "$i" -eq 14 ] && map_name="henesys_hunting_ground"
        [ "$region_id" = "starter_fields" ] && [ "$i" -eq 14 ] && map_name="forest_edge"
        [ "$region_id" = "sleepywood_depths" ] && [ "$i" -eq 14 ] && map_name="ant_tunnel_1"
        [ "$region_id" = "perion_rocklands" ] && [ "$i" -eq 14 ] && map_name="perion_rocky"
      elif [ "$i" -le 72 ]; then
        map_name="${region_id}_dungeon_$(printf '%02d' "$((i - 58))")"
      else
        map_name="${region_id}_hidden_$(printf '%02d' "$((((i - 73) % 3) + 1))")"
      fi
      quest_pool=$(join_by_pipe "dbexp_${region_id}_quest_$(printf '%03d' "$(((i - 1) % 65 + 1))")" "dbexp_${region_id}_quest_$(printf '%03d' "$(((i + 14) % 65 + 1))")")
      shop_inventory=$(join_by_pipe "dbexp_${region_id}_weapon_$(((i - 1) % 92 + 1))" "dbexp_${region_id}_consumable_$(((i - 1) % 80 + 1))" "dbexp_${region_id}_material_$(((i - 1) % 40 + 1))")
      personality="${region_name} ${role} keeps the route pressure readable and warns about boss cycles."
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$npc_id" "${region_name} ${role} ${i}" "$role" "$region_id" "$map_name" \
        "$((20 + (i * 7) % 180))" "$((4 + (i * 5) % 36))" "$shop_inventory" "$quest_pool" "$personality" >> "$data_dir/.npcs_append.tmp"
    done
  done
  cat "$data_dir/.npcs_append.tmp" >> "$data_dir/npcs.csv"
  rm -f "$data_dir/.npcs_append.tmp"
fi

if [ "$dialogues_existing" -lt 18000 ]; then
  dialogue_id=$(max_numeric_id "$data_dir/dialogues.csv")
  : > "$data_dir/.dialogues_append.tmp"
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for npc_local in $(seq 1 77); do
      if [ "$npc_local" -le 13 ]; then
        map_name="${region_id}_town_$(printf '%02d' "$npc_local")"
        [ "$region_id" = "henesys_plains" ] && [ "$npc_local" -eq 1 ] && map_name="henesys_town"
      elif [ "$npc_local" -le 58 ]; then
        map_name="${region_id}_combat_$(printf '%02d' "$((npc_local - 13))")"
        [ "$region_id" = "henesys_plains" ] && [ "$npc_local" -eq 14 ] && map_name="henesys_hunting_ground"
        [ "$region_id" = "starter_fields" ] && [ "$npc_local" -eq 14 ] && map_name="forest_edge"
        [ "$region_id" = "sleepywood_depths" ] && [ "$npc_local" -eq 14 ] && map_name="ant_tunnel_1"
        [ "$region_id" = "perion_rocklands" ] && [ "$npc_local" -eq 14 ] && map_name="perion_rocky"
      elif [ "$npc_local" -le 72 ]; then
        map_name="${region_id}_dungeon_$(printf '%02d' "$((npc_local - 58))")"
      else
        map_name="${region_id}_hidden_$(printf '%02d' "$((((npc_local - 73) % 3) + 1))")"
      fi
      npc_lookup=$(nth_region_npc_id "$region_id" "$npc_local")
      if [ -z "${npc_lookup:-}" ]; then
        continue
      fi
      for t in $(seq 1 20); do
        dialogue_id=$((dialogue_id + 1))
        dtype="${dialogue_types[$(((t - 1) % ${#dialogue_types[@]}))]}"
        quest_ref="dbexp_${region_id}_quest_$(printf '%03d' "$(((npc_local + t - 2) % 65 + 1))")"
        boss_ref=$(nth_prefixed_id "$data_dir/boss.csv" "dbexp_${region_id}_boss_" "$(((t - 1) % 5 + 1))")
        [ -z "${boss_ref:-}" ] && boss_ref="dbexp_${region_id}_boss_001"
        ref="$quest_ref"
        [ "$dtype" = "boss_rumor" ] && ref="$boss_ref"
        next_id=$((dialogue_id + 1))
        if [ "$t" -eq 20 ]; then next_id=0; fi
        nearby_mob=$(nth_prefixed_id "$data_dir/mobs.csv" "dbexp_${region_id}_mob_" "$(((t - 1) % 64 + 1))")
        [ -z "${nearby_mob:-}" ] && nearby_mob="dbexp_${region_id}_mob_0001"
        text="${region_name} ${dtype} ${t} points toward ${map_name} and warns about ${boss_ref} while naming nearby ${nearby_mob}."
        printf '%s,%s,%s,%s,%s,%s,%s\n' \
          "$dialogue_id" "$npc_lookup" "$map_name" "$dtype" "$ref" "$text" "$next_id" >> "$data_dir/.dialogues_append.tmp"
      done
    done
  done
  cat "$data_dir/.dialogues_append.tmp" >> "$data_dir/dialogues.csv"
  rm -f "$data_dir/.dialogues_append.tmp"
fi

append_unique_lines() {
  local file="$1"
  local temp="$2"
  if [ -s "$temp" ]; then
    cat "$temp" >> "$file"
  fi
  rm -f "$temp"
}

mobs_existing=$(line_count_no_header "$data_dir/mobs.csv")
if [ "$mobs_existing" -lt 960 ]; then
  existing_expansion_mobs=$(count_existing_prefix "$data_dir/mobs.csv" "dbexp_")
  needed=$((960 - mobs_existing))
  if [ "$needed" -lt 0 ]; then needed=0; fi
  generated=0
  : > "$data_dir/.mobs_append.tmp"
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for family_index in $(seq 0 7); do
      family="${families[$family_index]}"
      for variant in $(seq 1 8); do
        [ "$generated" -ge "$needed" ] && break 3
        serial=$((existing_expansion_mobs + generated + 1))
        prefix="${mob_prefixes[$(((variant + family_index) % ${#mob_prefixes[@]}))]}"
        suffix="${mob_suffixes[$(((variant + family_index * 2) % ${#mob_suffixes[@]}))]}"
        map_slot=$(( (family_index * 9 + variant) % 75 + 1 ))
        map_name="${region_id}_combat_$(printf '%02d' "$map_slot")"
        [ "$region_id" = "henesys_plains" ] && [ "$map_slot" -eq 1 ] && map_name="henesys_hunting_ground"
        [ "$region_id" = "starter_fields" ] && [ "$map_slot" -eq 1 ] && map_name="forest_edge"
        [ "$region_id" = "sleepywood_depths" ] && [ "$map_slot" -eq 1 ] && map_name="ant_tunnel_1"
        [ "$region_id" = "perion_rocklands" ] && [ "$map_slot" -eq 1 ] && map_name="perion_rocky"
        level=$((lvl_min + family_index * 4 + variant))
        hp=$((60 + level * 18 + variant * 23))
        exp=$((18 + level * 3 + variant * 5))
        mesos_min=$((4 + level / 4))
        mesos_max=$((mesos_min + 8 + variant))
        respawn=5
        [ $((variant % 3)) -eq 0 ] && respawn=7
        [ "$variant" -ge 7 ] && respawn=9
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
          "dbexp_${region_id}_mob_$(printf '%04d' "$serial")" \
          "${region_name} ${prefix} ${suffix}" \
          "$level" "$hp" "$exp" "$mesos_min" "$mesos_max" "$map_name" "$respawn" \
          "mob/dbexp_${region_id}_mob_$(printf '%04d' "$serial")" >> "$data_dir/.mobs_append.tmp"
        generated=$((generated + 1))
      done
    done
  done
  append_unique_lines "$data_dir/mobs.csv" "$data_dir/.mobs_append.tmp"
fi

boss_existing=$(line_count_no_header "$data_dir/boss.csv")
if [ "$boss_existing" -lt 96 ]; then
  existing_expansion_bosses=$(count_existing_prefix "$data_dir/boss.csv" "dbexp_")
  needed=$((96 - boss_existing))
  if [ "$needed" -lt 0 ]; then needed=0; fi
  generated=0
  : > "$data_dir/.boss_append.tmp"
  boss_types=(field regional dungeon hidden apex)
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for type_index in $(seq 0 4); do
      [ "$generated" -ge "$needed" ] && break 2
      serial=$((existing_expansion_bosses + generated + 1))
      boss_type="${boss_types[$type_index]}"
      spawn_map="${region_id}_combat_15"
      [ "$boss_type" = "regional" ] && spawn_map="${region_id}_combat_45"
      [ "$boss_type" = "dungeon" ] && spawn_map="${region_id}_dungeon_12"
      [ "$boss_type" = "hidden" ] && spawn_map="${region_id}_hidden_02"
      [ "$boss_type" = "apex" ] && spawn_map="${region_id}_dungeon_16"
      hp=$((12000 + lvl_max * 240 + type_index * 3800))
      cooldown=$((1800 + type_index * 600 + lvl_min * 3))
      printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_boss_$(printf '%03d' "$serial")" \
        "${region_name} ${boss_type} sovereign" \
        "$spawn_map" \
        "$hp" \
        "scheduled_window" \
        "$cooldown" \
        "dbexp_${region_id}_${boss_type}_drops" \
        "boss/dbexp_${region_id}_boss_$(printf '%03d' "$serial")" >> "$data_dir/.boss_append.tmp"
      generated=$((generated + 1))
    done
  done
  append_unique_lines "$data_dir/boss.csv" "$data_dir/.boss_append.tmp"
fi

items_existing=$(line_count_no_header "$data_dir/items.csv")
if [ "$items_existing" -lt 5200 ]; then
  existing_expansion_items=$(count_existing_prefix "$data_dir/items.csv" "dbexp_")
  : > "$data_dir/.items_append.tmp"
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for i in $(seq 1 92); do
      subtype="${weapon_subtypes[$(((i - 1) % ${#weapon_subtypes[@]}))]}"
      rarity="${rarities[$(((i - 1) % ${#rarities[@]}))]}"
      job="${weapon_jobs[$(((i - 1) % ${#weapon_jobs[@]}))]}"
      attack=$((12 + i + lvl_min / 2))
      defense=$((i % 7))
      req=$((lvl_min + (i - 1) / 3))
      name="${region_name} ${job} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_weapon_$i" "$name" "weapon" "$req" "$attack" "$defense" "false" \
        "$((200 + i * 17 + lvl_min * 5))" "$rarity" "item/dbexp_${region_id}_weapon_$i" \
        "$((1 + req / 10))" "${region_id} ${job} progression" "${region_id}_forge" "route_drop" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 125); do
      subtype="${armor_subtypes[$(((i - 1) % ${#armor_subtypes[@]}))]}"
      rarity="${rarities[$((((i + 1) / 8) % ${#rarities[@]}))]}"
      req=$((lvl_min + (i - 1) / 4))
      attack=$((i % 5))
      defense=$((8 + i / 3))
      name="${region_name} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_armor_$i" "$name" "$subtype" "$req" "$attack" "$defense" "false" \
        "$((180 + i * 15 + lvl_min * 4))" "$rarity" "item/dbexp_${region_id}_armor_$i" \
        "$((1 + req / 10))" "${region_id} defense ladder" "${region_id}_refit" "set_piece" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 30); do
      rarity="${rarities[$((((i + 2) / 10) % ${#rarities[@]}))]}"
      req=$((lvl_min + i / 2))
      attack=$((2 + i / 3))
      defense=$((2 + i / 4))
      name="${region_name} accessory $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_accessory_$i" "$name" "accessory" "$req" "$attack" "$defense" "false" \
        "$((250 + i * 22 + lvl_min * 6))" "$rarity" "item/dbexp_${region_id}_accessory_$i" \
        "$((1 + req / 10))" "${region_id} utility set" "${region_id}_jewelcraft" "notable" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 80); do
      subtype="${consumable_subtypes[$(((i - 1) % ${#consumable_subtypes[@]}))]}"
      rarity="common"
      [ "$i" -gt 50 ] && rarity="uncommon"
      [ "$i" -gt 70 ] && rarity="rare"
      req=$((lvl_min + (i - 1) / 10))
      name="${region_name} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_consumable_$i" "$name" "consumable" "$req" "0" "0" "true" \
        "$((15 + i * 5 + lvl_min))" "$rarity" "item/dbexp_${region_id}_consumable_$i" \
        "$((1 + req / 12))" "${region_id} sustain loop" "" "support" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 40); do
      subtype="${material_subtypes[$(((i - 1) % ${#material_subtypes[@]}))]}"
      rarity="uncommon"
      [ "$i" -gt 20 ] && rarity="rare"
      [ "$i" -gt 34 ] && rarity="epic"
      req=$((lvl_min + i / 3))
      name="${region_name} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_material_$i" "$name" "material" "$req" "0" "0" "true" \
        "$((25 + i * 8 + lvl_min * 2))" "$rarity" "item/dbexp_${region_id}_material_$i" \
        "$((1 + req / 12))" "${region_id} crafting core" "${region_id}_forge" "crafting_cache" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 50); do
      subtype="${quest_item_subtypes[$(((i - 1) % ${#quest_item_subtypes[@]}))]}"
      req=$((lvl_min + i / 5))
      name="${region_name} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_quest_item_$i" "$name" "quest" "$req" "0" "0" "true" \
        "0" "common" "item/dbexp_${region_id}_quest_item_$i" \
        "$((1 + req / 15))" "${region_id} quest chain token" "" "story_step" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 25); do
      subtype="${etc_loot_subtypes[$(((i - 1) % ${#etc_loot_subtypes[@]}))]}"
      req=$((lvl_min + i / 4))
      name="${region_name} ${subtype} $(printf '%03d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_etc_$i" "$name" "loot" "$req" "0" "0" "true" \
        "$((8 + i * 4 + lvl_min))" "common" "item/dbexp_${region_id}_etc_$i" \
        "$((1 + req / 18))" "${region_id} sell loop" "" "steady" >> "$data_dir/.items_append.tmp"
    done
    for i in $(seq 1 10); do
      rarity="epic"
      [ "$i" -ge 7 ] && rarity="legendary"
      req=$((lvl_min + 15 + i))
      name="${region_name} trophy $(printf '%02d' "$i")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_trophy_$i" "$name" "trophy" "$req" "$((4 + i))" "$((4 + i / 2))" "false" \
        "$((900 + i * 75 + lvl_min * 8))" "$rarity" "item/dbexp_${region_id}_trophy_$i" \
        "$((2 + req / 12))" "${region_id} boss chase" "${region_id}_trophy_upgrade" "boss_signature" >> "$data_dir/.items_append.tmp"
    done
  done
  cat "$data_dir/.items_append.tmp" >> "$data_dir/items.csv"
  rm -f "$data_dir/.items_append.tmp"
fi

quests_existing=$(line_count_no_header "$data_dir/quests.csv")
if [ "$quests_existing" -lt 1080 ]; then
  needed=$((1080 - quests_existing))
  if [ "$needed" -lt 0 ]; then needed=0; fi
  generated=0
  : > "$data_dir/.quests_append.tmp"
  quest_types=(beginner_cleanup collection hunt_elimination delivery_travel npc_story_chain boss_intro repeatable hidden_trigger)
  for region_entry in "${regions[@]}"; do
    IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
    for i in $(seq 1 65); do
      [ "$generated" -ge "$needed" ] && break 2
      qtype="${quest_types[$(((i - 1) % ${#quest_types[@]}))]}"
      start_npc=$(nth_region_npc_id "$region_id" 1)
      end_npc=$(nth_region_npc_id "$region_id" "$((i % 20 + 1))")
      mob_target=$(nth_prefixed_id "$data_dir/mobs.csv" "dbexp_${region_id}_mob_" "$(((i - 1) % 64 + 1))")
      boss_target=$(nth_prefixed_id "$data_dir/boss.csv" "dbexp_${region_id}_boss_" "$(((i - 1) % 5 + 1))")
      [ -z "${start_npc:-}" ] && continue
      [ -z "${end_npc:-}" ] && end_npc="$start_npc"
      [ -z "${mob_target:-}" ] && mob_target="dbexp_${region_id}_mob_0001"
      [ -z "${boss_target:-}" ] && boss_target="dbexp_${region_id}_boss_001"
      objectives="kill:${mob_target}:6|collect:dbexp_${region_id}_quest_item_$(((i - 1) % 50 + 1)):2"
      if [ "$qtype" = "boss_intro" ] || [ "$qtype" = "hidden_trigger" ]; then
        objectives="kill:${boss_target}:1|collect:dbexp_${region_id}_trophy_$(((i - 1) % 10 + 1)):1"
      fi
      reward_item="dbexp_${region_id}_consumable_$(((i - 1) % 80 + 1)):2|dbexp_${region_id}_material_$(((i - 1) % 40 + 1)):1"
      chain_next="dbexp_${region_id}_quest_$(printf '%03d' "$((i < 65 ? i + 1 : 1))")"
      guidance="${region_name} sends players from ${region_id}_combat_01 toward ${region_id}_dungeon_16 before unlocking hidden arenas."
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "dbexp_${region_id}_quest_$(printf '%03d' "$i")" \
        "${region_name} ${qtype} $(printf '%03d' "$i")" \
        "$((lvl_min + (i - 1) / 2))" \
        "$objectives" \
        "$((180 + i * 24 + lvl_min * 6))" \
        "$((140 + i * 35 + lvl_min * 5))" \
        "$reward_item" \
        "$start_npc" \
        "$end_npc" \
        "${region_name} ${qtype} pushes players through connected route loops and boss rumors." \
        "${region_name} gear tokens plus mesos pacing." \
        "$guidance" >> "$data_dir/.quests_append.tmp"
      generated=$((generated + 1))
    done
  done
  cat "$data_dir/.quests_append.tmp" >> "$data_dir/quests.csv"
  rm -f "$data_dir/.quests_append.tmp"
fi

: > "$data_dir/.drops_append.tmp"
boss_id_map="$data_dir/.boss_ids.tmp"
awk -F, 'NR > 1 { print $1 "," $3 }' "$data_dir/boss.csv" > "$boss_id_map"
for region_entry in "${regions[@]}"; do
  IFS=: read -r region_id region_name lvl_min lvl_max theme <<< "$region_entry"
  awk -F, -v region="$region_id" '
    NR > 1 && index($1, "dbexp_" region "_mob_") == 1 { print $1 }
  ' "$data_dir/mobs.csv" | while IFS= read -r mob_id; do
    serial="${mob_id##*_}"
    numeric=$((10#$serial))
    common1="dbexp_${region_id}_etc_$(((numeric - 1) % 25 + 1))"
    common2="dbexp_${region_id}_consumable_$(((numeric - 1) % 80 + 1))"
    material="dbexp_${region_id}_material_$(((numeric - 1) % 40 + 1))"
    rare1="dbexp_${region_id}_weapon_$(((numeric - 1) % 92 + 1))"
    rare2="dbexp_${region_id}_armor_$(((numeric - 1) % 125 + 1))"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$mob_id" "$common1" "0.48" "1" "3" "common" "false" "steady" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$mob_id" "$common2" "0.26" "1" "2" "common" "false" "support" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$mob_id" "$material" "0.18" "1" "2" "uncommon" "false" "crafting_cache" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$mob_id" "$rare1" "0.04" "1" "1" "rare" "false" "notable" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$mob_id" "$rare2" "0.03" "1" "1" "rare" "false" "route_chase" >> "$data_dir/.drops_append.tmp"
  done
  awk -F, -v region="$region_id" '
    NR > 1 && index($1, "dbexp_" region "_boss_") == 1 { print $1 }
  ' "$data_dir/boss.csv" | while IFS= read -r boss_id; do
    serial="${boss_id##*_}"
    numeric=$((10#$serial))
    trophy="dbexp_${region_id}_trophy_$(((numeric - 1) % 10 + 1))"
    material="dbexp_${region_id}_material_$(((numeric - 1) % 40 + 1))"
    weapon="dbexp_${region_id}_weapon_$(((numeric - 1) % 92 + 1))"
    armor="dbexp_${region_id}_armor_$(((numeric - 1) % 125 + 1))"
    accessory="dbexp_${region_id}_accessory_$(((numeric - 1) % 30 + 1))"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$boss_id" "$weapon" "0.70" "1" "1" "epic" "false" "boss_signature" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$boss_id" "$armor" "0.62" "1" "1" "epic" "false" "boss_signature" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$boss_id" "$accessory" "0.55" "1" "1" "rare" "false" "jackpot" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$boss_id" "$material" "1.00" "3" "8" "rare" "false" "crafting_cache" >> "$data_dir/.drops_append.tmp"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$boss_id" "$trophy" "1.00" "1" "1" "legendary" "true" "trophy" >> "$data_dir/.drops_append.tmp"
  done
done

if [ -s "$data_dir/.drops_append.tmp" ]; then
  cat "$data_dir/.drops_append.tmp" >> "$data_dir/drops.csv"
fi
rm -f "$data_dir/.drops_append.tmp" "$boss_id_map"

ln -sfn data/maps.csv "$repo_root/maps.csv"
ln -sfn data/mobs.csv "$repo_root/mobs.csv"
ln -sfn data/boss.csv "$repo_root/boss.csv"
ln -sfn data/items.csv "$repo_root/items.csv"
ln -sfn data/quests.csv "$repo_root/quests.csv"
ln -sfn data/drops.csv "$repo_root/drops.csv"
ln -sfn data/npcs.csv "$repo_root/npcs.csv"
ln -sfn data/dialogues.csv "$repo_root/dialogues.csv"
ln -sfn data/runtime_tables.lua "$repo_root/runtime_tables.lua"

maps_count=$(line_count_no_header "$data_dir/maps.csv")
mobs_count=$(line_count_no_header "$data_dir/mobs.csv")
boss_count=$(line_count_no_header "$data_dir/boss.csv")
items_count=$(line_count_no_header "$data_dir/items.csv")
quests_count=$(line_count_no_header "$data_dir/quests.csv")
npcs_count=$(line_count_no_header "$data_dir/npcs.csv")
dialogues_count=$(line_count_no_header "$data_dir/dialogues.csv")

printf 'maps=%s\nmobs=%s\nbosses=%s\nitems=%s\nquests=%s\nnpcs=%s\ndialogues=%s\n' \
  "$maps_count" "$mobs_count" "$boss_count" "$items_count" "$quests_count" "$npcs_count" "$dialogues_count"
