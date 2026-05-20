
--////////////// LTC2308 //////////////////////////////
-- max 40mhz
--
-- rise edge to trigger
-- spi 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity capteurs_sol_seuil is
	port (
		clk	: in  std_logic;	-- max 40mhz
		reset_n	: in  std_logic;
	--
		data_capture	: in  std_logic;	-- rise edge to trigger
		data_readyr	: out std_logic;
		data0r	: out std_logic_vector(7 downto 0);
		data1r	: out std_logic_vector(7 downto 0);
		data2r	: out std_logic_vector(7 downto 0);
		data3r	: out std_logic_vector(7 downto 0);
		data4r	: out std_logic_vector(7 downto 0);
		data5r	: out std_logic_vector(7 downto 0);
		data6r	: out std_logic_vector(7 downto 0);
		-- data7 n'est pas un capteur
--		data7r	: out std_logic_vector(7 downto 0);
	-- entree/sortie signaux seuilles
	   NIVEAU : in std_logic_vector(7 downto 0);
		vect_capt : out std_logic_vector(6 downto 0);
	-- spi 
		ADC_CONVSTr	: out std_logic;
		ADC_SCK	: out std_logic;
		ADC_SDIr	: out std_logic;
		ADC_SDO	: in  std_logic 

	);
end capteurs_sol_seuil;

architecture RTL of capteurs_sol_seuil is



-- WARNING(5) in line 43: Please write a signal width part in the following sentence, manually.
	constant CLOCK_DUR	: integer := 25;	-- 25ns = 40MHz

-- WARNING(5) in line 44: Please write a signal width part in the following sentence, manually.
	constant CONVST_WAIT_CLOCK_NUM	: integer := ((1600 + CLOCK_DUR - 1) / CLOCK_DUR);	--  1.6 us = 1600 ns, 1600/25=64

	--`define DATA_BIT_LENGTH	12
	--`define CHANNEL_NUM		8

	signal data_ready	: std_logic;
	signal data0	: std_logic_vector(11 downto 0);
	signal data1	: std_logic_vector(11 downto 0);
	signal data2	: std_logic_vector(11 downto 0);
	signal data3	: std_logic_vector(11 downto 0);
	signal data4	: std_logic_vector(11 downto 0);
	signal data5	: std_logic_vector(11 downto 0);
	signal data6	: std_logic_vector(11 downto 0);
	signal data7	: std_logic_vector(11 downto 0);
	
	-- vecteur de signaux compactés
	signal vect_data : std_logic_vector(55 downto 0);
	
	-- spi 
	signal ADC_CONVST	: std_logic;
	signal ADC_SDI, ADC_SCKl	: std_logic;

	--///////////////////////////////////////////
	-- trigger

	signal pre_data_capture	: std_logic;

	signal data_capture_trigger	: std_logic;
	--////////////////////////////////////////////
	-- state control

	-- state
	TYPE State_type IS (S0,S1,S2,S3,S4,S5,S6,S7);  -- Define the states
	SIGNAL State : State_Type; 
--	signal state	: std_logic_vector(2 downto 0);
  
	-- CONVT wait
	signal wait_tick_cnt	: unsigned (7 downto 0);	-- max 64

	-- data bit index
	signal last_data_bits	: std_logic;
	signal data_bit_index	: std_logic_vector(3 downto 0);

	-- adc channel
	signal last_channel	: std_logic;
	signal channel	: std_logic_vector(3 downto 0);

	--////////////////////////
	-- generate SCK
	signal spi_clk_enable	: std_logic;

	--////////////////////////
	-- generate SDI,  unipolar, not sleep
	signal channel_config	: std_logic_vector(5 downto 0);

	-- note, SDI ready at posedge clk (negtive ADC_SCK)
	signal sdi_data_bit_index	: std_logic_vector(3 downto 0);

	--////////////////////////
	-- receive data from SDO
	signal rx_data_bit_index	: std_logic_vector(3 downto 0);

begin

	data_readyr	<= data_ready;
	-- spi 
	ADC_CONVSTr	<= ADC_CONVST;
	ADC_SDIr	<= ADC_SDI;

	v2v_pr_1:process (clk, reset_n)
	     variable ii : integer;
	begin
		if (not (reset_n = '1')) then
			     state	<= S0;
			     data_bit_index	<= (others => '0');
			     wait_tick_cnt	<= to_unsigned(0,8);
			     ADC_SDI	<= '0';
				  ADC_CONVST	<= '0';
				  spi_clk_enable	<= '0';
		elsif ( clk'event and (clk = '1')) then
		        case(state) is
		              when S0 => 
		                        channel	<= (others => '0');
										data_ready	<= '0';
		                        if (data_capture = '1') then
				                            state	<= S1;                          
													 ADC_CONVST	<= '1';
				                  end if;
		              when S1 =>
		                        wait_tick_cnt	<= to_unsigned(0,8);
										ADC_CONVST	<= '1';
		                        state <= S2;
		              when S2 =>
										spi_clk_enable	<= '0';
										ADC_CONVST	<= '0';
		                        ADC_SDI <= '0';
		                        wait_tick_cnt	<= wait_tick_cnt + 1;
		                        data_bit_index	<= (others => '0');
		                        if (wait_tick_cnt >= to_unsigned(CONVST_WAIT_CLOCK_NUM,8)) then
					                           state	<= S3; 
				                    end if;  
		              when S3 =>
										spi_clk_enable	<= '1';
		                        if (unsigned(data_bit_index) < 6) then 
--		                          sdi_data_bit_index	<= 5 - data_bit_index;
                                          ii:= to_integer(5 - unsigned(data_bit_index));
				                              ADC_SDI	<= channel_config(ii);
				                    else
				                              ADC_SDI	<= '0';
				                    end if;
				                    
		                        data_bit_index	<= std_logic_vector(unsigned(data_bit_index) + 1);
		                        if (unsigned(data_bit_index) >= 11) then --(last_data_bits = '1') then
					                           state	<= S4;
				                   end if;
		              when S4 =>
										spi_clk_enable	<= '0';
		                        channel	<= std_logic_vector (unsigned(channel) + 1);
		                        if (channel = "1000") then -- (last_channel = '1') then
																			state	<= S5;
																			data_ready	<= '1';
																			data0r	<= data0(11 downto 4);
																			data1r	<= data1(11 downto 4);
																			data2r	<= data2(11 downto 4);
																			data3r	<= data3(11 downto 4);
																			data4r	<= data4(11 downto 4);
																			data5r	<= data5(11 downto 4);
																			data6r	<= data6(11 downto 4);
																			--data7r	<= data7(11 downto 4);
				                    else
					                           state	<= S1;
														ADC_CONVST	<= '1';
				                    end if;
							when S5 => if (data_capture = '0') then
				                            state	<= S0;
				                    end if;
		              when others => null; 
		        end case;
		end if;
	end process;



	ADC_SCKl	<= not clk	when (spi_clk_enable = '1')
			else '0';	-- note. clock is invert 

	v2v_pr_8:process (channel)
	begin
		case (channel) is
		when "1000" =>
		-- ch0
			channel_config	<= "100010";
		when "0000" =>
		-- ch0
			channel_config	<= "100010";
		when "0001" =>
			channel_config	<= "110010";
		when "0010" =>
			channel_config	<= "100110";
		when "0011" =>
			channel_config	<= "110110";
		when "0100" =>
			channel_config	<= "101010";
		when "0101" =>
			channel_config	<= "111010";
		when "0110" =>
			channel_config	<= "101110";
		when "0111" =>
			channel_config	<= "111110";
		when Others => Null;
		end case;
	end process;

	
	
	rx_data_bit_index	<= std_logic_vector(12 - unsigned(data_bit_index));	-- data valid when data_bit_index = 1~12

	-- read data at posedge of ADC_SCK
	ADC_SCK <= ADC_SCKl;
	v2v_pr_10:process (ADC_SCKl)
	begin
	  
		if (ADC_SCKl'event and ADC_SCKl = '1') then
			case (channel) is
			when "0001" =>
			  data0 <= data0(10 downto 0) & ADC_SDO;			
			when "0010" =>
			  data1 <= data1(10 downto 0) & ADC_SDO;			
			when "0011" =>
			  data2 <= data2(10 downto 0) & ADC_SDO;			
			when "0100" =>
			  data3 <= data3(10 downto 0) & ADC_SDO;				
			when "0101" =>
			  data4 <= data4(10 downto 0) & ADC_SDO;			
			when "0110" =>
			  data5 <= data5(10 downto 0) & ADC_SDO; 
			
			when "0111" =>
			  data6 <= data6(10 downto 0) & ADC_SDO;				
			when "1000" =>
			  data7 <= data7(10 downto 0) & ADC_SDO;				
			when others => null;
			end case;
		end if;
	end process;
	
	
	vect_data <= data6(11 downto 4)& data5(11 downto 4)&
					 data4(11 downto 4)& data3(11 downto 4)& 
					 data2(11 downto 4)&data1(11 downto 4)& data0(11 downto 4);
																		
	-- Seuillage des valeurs mesurées par les capteurs		
		bloc : for i in 0 to 6 generate
		  begin 
					vect_capt(i) <=  '1' when (unsigned(vect_data(7+i*8 downto i*8))>unsigned(NIVEAU)) else
							  '0';
		 end generate;

end RTL;
