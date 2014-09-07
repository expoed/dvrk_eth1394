
# PlanAhead Launch Script for Post-Synthesis floorplanning, created by Project Navigator

create_project -name EthernetTest -dir "C:/Users/Qian/Desktop/Project/Ethernet/EthernetTest/planAhead_run_2" -part xc6slx45fgg484-3
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "C:/Users/Qian/Desktop/Project/Ethernet/EthernetTest/EthernetTest.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {C:/Users/Qian/Desktop/Project/Ethernet/EthernetTest} {ipcore_dir} }
add_files [list {ipcore_dir/EthernetInit_icon.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/EthernetInit_ila.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/Ethernet_icon.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/Ethernet_ila.ncf}] -fileset [get_property constrset [current_run]]
set_property target_constrs_file "EthernetUCF.ucf" [current_fileset -constrset]
add_files [list {EthernetUCF.ucf}] -fileset [get_property constrset [current_run]]
open_netlist_design
