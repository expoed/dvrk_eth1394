
rem Clean up the results directory
rmdir /S /Q results
mkdir results

rem Synthesize the VHDL Wrapper Files


echo 'Synthesizing example design with XST';
xst -ifn xst.scr
copy Hub_Mem_top.ngc .\results\


rem Copy the netlist generated by Coregen
echo 'Copying files from the netlist directory to the results directory'
copy ..\..\Hub_Mem.ngc results\


rem  Copy the constraints files generated by Coregen
echo 'Copying files from constraints directory to results directory'
copy ..\example_design\Hub_Mem_top.ucf results\

cd results

echo 'Running ngdbuild'
ngdbuild -p xc6slx45-fgg484-3 Hub_Mem_top

echo 'Running map'
map Hub_Mem_top -o mapped.ncd -pr i

echo 'Running par'
par mapped.ncd routed.ncd

echo 'Running trce'
trce -e 10 routed.ncd mapped.pcf -o routed

echo 'Running design through bitgen'
bitgen -w routed

echo 'Running netgen to create gate level Verilog model'
netgen -ofmt verilog -sim -tm Hub_Mem_top -pcf mapped.pcf -w -sdf_anno false routed.ncd routed.v
