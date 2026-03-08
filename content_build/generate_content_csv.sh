#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

regions=(
  "henesys:1"
  "ellinia:18"
  "perion:34"
  "kerning:48"
  "lith_harbor:8"
  "ant_tunnel:28"
  "sleepywood:42"
  "dungeon:58"
  "forest:72"
  "desert:90"
)

equipment_bases=(
  "bronze_blade:weapon:10:0:common"
  "maple_staff:weapon:8:1:common"
  "shadow_claw:weapon:9:0:common"
  "wind_bow:weapon:9:0:common"
  "cannon_knuckle:weapon:10:0:common"
  "field_mail:overall:0:6:common"
  "scout_hat:hat:0:4:common"
  "traveler_gloves:glove:1:2:common"
  "wanderer_boots:shoe:0:3:common"
  "hero_charm:accessory:2:2:uncommon"
  "guard_shield:accessory:0:4:uncommon"
  "storm_pendant:accessory:3:1:uncommon"
  "warden_plate:overall:0:8:uncommon"
  "ritual_cap:hat:1:5:uncommon"
  "hunter_wraps:glove:2:2:uncommon"
  "pathrunner_boots:shoe:0:4:uncommon"
  "sentinel_blade:weapon:12:0:rare"
  "oracle_orb:weapon:11:2:rare"
  "captain_emblem:accessory:3:3:rare"
  "region_crest:accessory:4:2:rare"
)

consumables=(
  "potion_01:Route Potion:30"
  "potion_02:Field Potion:60"
  "potion_03:Dungeon Potion:120"
  "potion_04:Boss Potion:260"
  "elixir_01:Mana Draft:90"
  "elixir_02:Focus Draft:140"
  "elixir_03:Guard Draft:200"
  "tonic_01:Route Tonic:75"
  "tonic_02:Party Tonic:150"
  "tonic_03:Raid Tonic:300"
)

mob_names=(
  crawler shellling sporeling fungal_guard twig_stalker thorn_howler grave_sentry wraith_lancer
  sand_beast dune_alpha ember_sprite storm_wisp vault_golem chain_keeper elite_hunter elite_bruiser
  rare_marauder rare_oracle guardian champion
)

mob_maps=(
  outskirts fields fields upper_route lower_route grove ruins tunnel tunnel clash_zone
  fields sanctum dungeon dungeon ruins clash_zone grove clash_zone sanctum boss
)

{
  echo "mob_id,name,level,hp,exp,mesos_min,mesos_max,map_pool,respawn_sec,asset_key"
  for region in "${regions[@]}"; do
    IFS=: read -r region_id base_level <<< "$region"
    for i in $(seq 1 20); do
      idx=$((i-1))
      mob_key="${mob_names[$idx]}"
      map_suffix="${mob_maps[$idx]}"
      level=$((base_level + i))
      hp=$((24 + (level * 6) + (i * 28)))
      exp=$((10 + (level / 2) + (i * 5)))
      mesos_min=$((3 + i + (base_level / 4)))
      mesos_max=$((mesos_min + 5 + i))
      respawn=5
      if [ "$i" -ge 15 ]; then respawn=9; elif [ "$i" -ge 8 ]; then respawn=7; fi
      echo "${region_id}_mob_$(printf '%02d' "$i"),$(tr '_' ' ' <<< "$region_id") $(tr '_' ' ' <<< "$mob_key"),$level,$hp,$exp,$mesos_min,$mesos_max,${region_id}_${map_suffix},$respawn,mob/${region_id}_mob_$(printf '%02d' "$i")"
    done
  done
  echo "snail,Snail,1,12,8,1,3,henesys_hunting_ground,5,mob/snail"
  echo "orange_mushroom,Orange Mushroom,8,80,18,6,12,henesys_hunting_ground,7,mob/orange_mushroom"
  echo "horny_mushroom,Horny Mushroom,22,260,52,24,35,ant_tunnel_1,9,mob/horny_mushroom"
  echo "zombie_mushroom,Zombie Mushroom,24,340,70,28,40,ant_tunnel_1,10,mob/zombie_mushroom"
} > data/mobs.csv

{
  echo "item_id,name,type,required_level,attack,defense,stackable,npc_price,rarity,asset_key,progression_tier,desirability,upgrade_path,excitement"
  for region in "${regions[@]}"; do
    IFS=: read -r region_id base_level <<< "$region"
    region_name="$(tr '_' ' ' <<< "$region_id")"
    item_index=0
    for base in "${equipment_bases[@]}"; do
      IFS=: read -r item_key item_type atk def rarity <<< "$base"
      for tier in 1 2 3; do
        item_index=$((item_index + 1))
        req=$((base_level + (item_index % 6) + ((tier - 1) * 8)))
        iatk=$((atk + (tier - 1) * 6))
        idef=$((def + (tier - 1) * 4))
        price=$((120 + item_index * 25 + tier * 80))
        final_rarity="$rarity"
        if [ "$tier" -eq 2 ]; then
          if [ "$rarity" = "common" ]; then final_rarity="uncommon"; else final_rarity="rare"; fi
        elif [ "$tier" -eq 3 ]; then
          if [ "$rarity" = "rare" ]; then final_rarity="legendary"; else final_rarity="epic"; fi
        fi
        item_id="${region_id}_${item_key}"
        if [ "$tier" -gt 1 ]; then item_id="${item_id}_t${tier}"; fi
        excitement="steady"
        if [ "$final_rarity" = "epic" ]; then excitement="boss_signature"; fi
        if [ "$final_rarity" = "legendary" ]; then excitement="jackpot"; fi
        echo "${item_id},${region_name} ${item_key//_/ } Mk ${tier},${item_type},${req},${iatk},${idef},false,${price},${final_rarity},item/${item_id},$((tier + base_level / 10)),set completion,${region_id}_reforge,${excitement}"
      done
    done
    for i in $(seq 1 20); do
      item_id="${region_id}_material_$(printf '%02d' "$i")"
      rarity="common"; if [ "$i" -ge 8 ]; then rarity="uncommon"; fi; if [ "$i" -ge 15 ]; then rarity="rare"; fi
      echo "${item_id},${region_name} Material $(printf '%02d' "$i"),material,$((base_level + i / 2)),0,0,true,$((10 + i + base_level / 2)),${rarity},item/${item_id},$((base_level / 10 + i / 3)),crafting,,steady"
    done
    for i in $(seq 1 10); do
      item_id="${region_id}_artifact_$(printf '%02d' "$i")"
      rarity="rare"; if [ "$i" -ge 5 ]; then rarity="epic"; fi; if [ "$i" -ge 8 ]; then rarity="legendary"; fi
      excitement="boss_signature"; if [ "$rarity" = "legendary" ]; then excitement="jackpot"; fi
      echo "${item_id},${region_name} Artifact $(printf '%02d' "$i"),accessory,$((base_level + 6 + i)),$((2 + i)),$((2 + i / 2)),false,$((400 + i * 60 + base_level * 3)),${rarity},item/${item_id},$((base_level / 10 + 8 + i)),boss-exclusive,,${excitement}"
    done
    for c in "${consumables[@]}"; do
      IFS=: read -r cid cname price <<< "$c"
      excitement="steady"; rarity="common"
      if [ "$cid" = "tonic_03" ]; then rarity="rare"; excitement="boss_prep"; fi
      item_id="${region_id}_${cid}"
      echo "${item_id},${region_name} ${cname},consumable,${base_level},0,0,true,$((price + base_level / 2)),${rarity},item/${item_id},$((base_level / 10 + 1)),sustain,,${excitement}"
    done
    for i in $(seq 1 10); do
      item_id="${region_id}_scroll_$(printf '%02d' "$i")"
      rarity="uncommon"; if [ "$i" -ge 5 ]; then rarity="rare"; fi; if [ "$i" -ge 8 ]; then rarity="epic"; fi
      echo "${item_id},${region_name} Scroll $(printf '%02d' "$i"),material,$((base_level + i)),0,0,true,$((80 + i * 15 + base_level)),${rarity},item/${item_id},$((base_level / 10 + i)),enhancement,,route_upgrade"
    done
    for i in $(seq 1 10); do
      item_id="${region_id}_relic_$(printf '%02d' "$i")"
      rarity="rare"; if [ "$i" -ge 8 ]; then rarity="epic"; fi
      echo "${item_id},${region_name} Relic $(printf '%02d' "$i"),material,$((base_level + i)),0,0,true,0,${rarity},item/${item_id},$((base_level / 10 + i)),quest,,lore_find"
    done
  done
  echo "sword_bronze,Bronze Sword,weapon,5,12,0,false,180,common,item/sword_bronze,5,legacy progression,,steady"
  echo "wooden_armor,Wooden Armor,overall,3,0,8,false,140,common,item/wooden_armor,3,legacy progression,,steady"
  echo "hp_potion,HP Potion,consumable,1,0,0,true,20,common,item/hp_potion,1,sustain,,steady"
  echo "mushcap_hat,Mushcap Hat,hat,10,0,6,false,220,uncommon,item/mushcap_hat,10,legacy progression,,steady"
  echo "zombie_glove,Zombie Glove,glove,20,4,3,false,560,rare,item/zombie_glove,20,legacy progression,,notable"
  echo "mano_shell,Mano Shell,accessory,15,2,2,false,1000,rare,item/mano_shell,15,legacy chase,,boss_signature"
  echo "stumpy_axe,Stumpy Axe,weapon,30,38,0,false,2400,epic,item/stumpy_axe,30,legacy chase,,jackpot"
  echo "snail_shell,Snail Shell,material,1,0,0,true,5,common,item/snail_shell,1,legacy progression,,steady"
  echo "mushroom_spore,Mushroom Spore,material,1,0,0,true,12,common,item/mushroom_spore,1,legacy progression,,steady"
} > data/items.csv

{
  echo "boss_id,name,map_id,hp,trigger,cooldown_sec,rare_drop_group,asset_key"
  for region in "${regions[@]}"; do
    IFS=: read -r region_id base_level <<< "$region"
    region_name="$(tr '_' ' ' <<< "$region_id")"
    echo "${region_id}_warden,${region_name} Warden,${region_id}_clash_zone,$((3200 + base_level * 90)),scheduled_window,$((720 + base_level * 2)),${region_id}_warden_drops,boss/${region_id}_warden"
    echo "${region_id}_overseer,${region_name} Overseer,${region_id}_boss,$((5200 + base_level * 110)),scheduled_window,$((1100 + base_level * 2)),${region_id}_overseer_drops,boss/${region_id}_overseer"
    echo "${region_id}_tyrant,${region_name} Tyrant,${region_id}_sanctum,$((8600 + base_level * 130)),scheduled_window,$((1500 + base_level * 3)),${region_id}_tyrant_drops,boss/${region_id}_tyrant"
    echo "${region_id}_raid_core,${region_name} Raid Core,${region_id}_boss,$((12800 + base_level * 160)),scheduled_window,$((2100 + base_level * 4)),${region_id}_raid_core_drops,boss/${region_id}_raid_core"
  done
  echo "mano,Mano,forest_edge,5000,channel_presence,1800,mano_rares,boss/mano"
  echo "stumpy,Stumpy,perion_rocky,12000,scheduled_window,2700,stumpy_rares,boss/stumpy"
} > data/boss.csv

{
  echo "mob_id,item_id,chance,min_qty,max_qty,rarity,bind_on_pickup,anticipation"
  for region in "${regions[@]}"; do
    IFS=: read -r region_id base_level <<< "$region"
    for i in $(seq 1 20); do
      mob_id="${region_id}_mob_$(printf '%02d' "$i")"
      mat="${region_id}_material_$(printf '%02d' $((((i - 1) % 20) + 1)))"
      cons="${region_id}_potion_$(printf '%02d' $((((i - 1) % 4) + 1)))"
      if [ $((i % 3)) -eq 0 ]; then
        bonus="${region_id}_scroll_$(printf '%02d' $((((i - 1) % 10) + 1)))"
      else
        bonus="${region_id}_bronze_blade"
      fi
      rare="common"; if [ "$i" -ge 8 ]; then rare="uncommon"; fi; if [ "$i" -ge 15 ]; then rare="rare"; fi
      echo "${mob_id},${mat},0.62,1,3,${rare},false,steady"
      echo "${mob_id},${cons},0.24,1,2,common,false,support"
      echo "${mob_id},${bonus},0.05,1,1,rare,false,notable"
    done
    for boss in warden overseer tyrant raid_core; do
      boss_id="${region_id}_${boss}"
      echo "${boss_id},${region_id}_artifact_01,0.45,1,1,epic,false,boss_signature"
      echo "${boss_id},${region_id}_material_20,1.0,3,8,rare,false,crafting_cache"
      echo "${boss_id},${region_id}_bronze_blade_t3,0.60,1,1,epic,false,jackpot"
    done
  done
  echo "snail,snail_shell,0.65,1,2,common,false,steady"
  echo "snail,hp_potion,0.15,1,1,common,false,support"
  echo "orange_mushroom,mushroom_spore,0.55,1,2,common,false,steady"
  echo "orange_mushroom,mushcap_hat,0.06,1,1,uncommon,false,notable"
  echo "horny_mushroom,wooden_armor,0.08,1,1,common,false,steady"
  echo "horny_mushroom,hp_potion,0.45,1,3,common,false,support"
  echo "zombie_mushroom,zombie_glove,0.04,1,1,rare,false,jackpot"
  echo "zombie_mushroom,hp_potion,0.35,1,2,common,false,support"
  echo "mano,mano_shell,1.0,1,1,rare,false,boss_signature"
  echo "mano,sword_bronze,0.25,1,1,uncommon,false,notable"
  echo "stumpy,stumpy_axe,1.0,1,1,epic,false,jackpot"
  echo "stumpy,wooden_armor,0.2,1,1,common,false,steady"
} > data/drops.csv

{
  echo "quest_id,name,required_level,objectives,reward_exp,reward_mesos,reward_items,start_npc,end_npc,narrative,reward_summary,guidance"
  for region in "${regions[@]}"; do
    IFS=: read -r region_id base_level <<< "$region"
    region_name="$(tr '_' ' ' <<< "$region_id")"
    for i in $(seq 1 30); do
      req=$((base_level + i - 1))
      if [ "$i" -le 20 ]; then
        kill_target="${region_id}_mob_$(printf '%02d' $((((i - 1) % 20) + 1)))"
        collect_target="${region_id}_material_$(printf '%02d' $((((i - 1) % 20) + 1)))"
        kill_req=$((5 + (i % 5)))
        collect_req=$((2 + (i % 4)))
      else
        boss_cycle=(warden overseer tyrant raid_core)
        boss="${boss_cycle[$(((i - 21) % 4))]}"
        kill_target="${region_id}_${boss}"
        collect_target="${region_id}_artifact_$(printf '%02d' $((((i - 21) % 10) + 1)))"
        kill_req=1
        collect_req=1
      fi
      reward_item="${region_id}_potion_03:1"
      if [ "$i" -gt 8 ] && [ "$i" -le 20 ]; then reward_item="${region_id}_bronze_blade:1"; fi
      if [ "$i" -gt 20 ]; then reward_item="${region_id}_artifact_01:1"; fi
      echo "${region_id}_story_$(printf '%02d' "$i"),${region_name} Campaign $(printf '%02d' "$i"),${req},kill:${kill_target}:${kill_req}|collect:${collect_target}:${collect_req},$((120 + i * 28 + base_level * 4)),$((180 + i * 46 + base_level * 6)),${reward_item},${region_id}_guide_01,${region_id}_captain_08,${region_name} progression chain step ${i},regional rewards and route unlock pressure,Rotate through local routes then move into dungeon and boss content as guidance advances."
    done
  done
  echo "q_snail_cleanup,Snail Cleanup,1,kill:snail:5,40,100,hp_potion:5,Rina,Rina,Rina wants the beginner route made safe.,starter sustain package,Stay on the lower path until five kills are secured."
  echo "q_spore_collection,Spore Collection,8,collect:mushroom_spore:4,120,260,hp_potion:3,Sera,Sera,Sera is rebuilding potion stock from mushroom spores.,consumables and mesos,Farm orange mushrooms until the potion loop feels self-sustaining."
  echo "q_mano_hunt,Mano Suppression,18,kill:mano:1,800,1200,mano_shell:1,Chief_Stan,Chief_Stan,Chief Stan needs proof that Mano has been broken.,boss trophy and pivot,Bring support items and burst the boss during safe windows."
} > data/quests.csv

echo "Generated CSV content volume:"
wc -l data/mobs.csv data/items.csv data/boss.csv data/drops.csv data/quests.csv
