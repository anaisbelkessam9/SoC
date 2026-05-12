
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity DE1_Basic_Computer is

-------------------------------------------------------------------------------
--                             Port Declarations                             --
-------------------------------------------------------------------------------
port (
	-- Inputs
	CLOCK_50             : in std_logic;
	CLOCK_27             : in std_logic;
	KEY                  : in std_logic_vector (3 downto 0);
	SW                   : in std_logic_vector (9 downto 0);

	--  Communication
	UART_RXD             : in std_logic;

	-- Bidirectionals
	GPIO_0               : inout std_logic_vector (35 downto 0);
	GPIO_1               : inout std_logic_vector (35 downto 0);

	-- Memory (SRAM)
	SRAM_DQ              : inout std_logic_vector (15 downto 0);
	
	-- Memory (SDRAM)
	DRAM_DQ				 : inout std_logic_vector (15 downto 0);

	-- Outputs
	--  Simple
	LEDG                 : out std_logic_vector (7 downto 0);
	LEDR                 : out std_logic_vector (9 downto 0);
	HEX0                 : out std_logic_vector (6 downto 0);
	HEX1                 : out std_logic_vector (6 downto 0);
	HEX2                 : out std_logic_vector (6 downto 0);
	HEX3                 : out std_logic_vector (6 downto 0);

	--  Memory (SRAM)
	SRAM_ADDR            : out std_logic_vector (17 downto 0);
	SRAM_CE_N            : out std_logic;
	SRAM_WE_N            : out std_logic;
	SRAM_OE_N            : out std_logic;
	SRAM_UB_N            : out std_logic;
	SRAM_LB_N            : out std_logic;

	--  Communication
	UART_TXD             : out std_logic;
	
	-- Memory (SDRAM)
	DRAM_ADDR			 : out std_logic_vector (11 downto 0);
	DRAM_BA_1			 : buffer std_logic;
	DRAM_BA_0			 : buffer std_logic;
	DRAM_CAS_N			 : out std_logic;
	DRAM_RAS_N			 : out std_logic;
	DRAM_CLK			 : out std_logic;
	DRAM_CKE			 : out std_logic;
	DRAM_CS_N			 : out std_logic;
	DRAM_WE_N			 : out std_logic;
	DRAM_UDQM			 : buffer std_logic;
	DRAM_LDQM			 : buffer std_logic
	);
end DE1_Basic_Computer;


architecture DE1_Basic_Computer_rtl of DE1_Basic_Computer is

-------------------------------------------------------------------------------
--                           Subentity Declarations                          --
-------------------------------------------------------------------------------
	component nios_system
		port (
              -- 1) global signals:
                 signal clk : IN STD_LOGIC;
                 signal reset_n : IN STD_LOGIC;

              -- the_Expansion_JP1
                 signal GPIO_0_to_and_from_the_Expansion_JP1 : INOUT STD_LOGIC_VECTOR (31 DOWNTO 0);

              -- the_Expansion_JP2
                 signal GPIO_1_to_and_from_the_Expansion_JP2 : INOUT STD_LOGIC_VECTOR (31 DOWNTO 0);

              -- the_Green_LEDs
                 signal LEDG_from_the_Green_LEDs : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);

              -- the_HEX3_HEX0
                 signal HEX0_from_the_HEX3_HEX0 : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
                 signal HEX1_from_the_HEX3_HEX0 : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
                 signal HEX2_from_the_HEX3_HEX0 : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
                 signal HEX3_from_the_HEX3_HEX0 : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);

              -- the_Pushbuttons
                 signal KEY_to_the_Pushbuttons : IN STD_LOGIC_VECTOR (3 DOWNTO 0);

              -- the_Red_LEDs
                 signal LEDR_from_the_Red_LEDs : OUT STD_LOGIC_VECTOR (9 DOWNTO 0);

              -- the_SRAM
                 signal SRAM_ADDR_from_the_SRAM : OUT STD_LOGIC_VECTOR (17 DOWNTO 0);
                 signal SRAM_CE_N_from_the_SRAM : OUT STD_LOGIC;
                 signal SRAM_DQ_to_and_from_the_SRAM : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0);
                 signal SRAM_LB_N_from_the_SRAM : OUT STD_LOGIC;
                 signal SRAM_OE_N_from_the_SRAM : OUT STD_LOGIC;
                 signal SRAM_UB_N_from_the_SRAM : OUT STD_LOGIC;
                 signal SRAM_WE_N_from_the_SRAM : OUT STD_LOGIC;

              -- the_Serial_port
                 signal UART_RXD_to_the_Serial_port : IN STD_LOGIC;
                 signal UART_TXD_from_the_Serial_port : OUT STD_LOGIC;

              -- the_Slider_switches
                 signal SW_to_the_Slider_switches : IN STD_LOGIC_VECTOR (9 DOWNTO 0);
                 
              -- the_sdram
                 signal zs_addr_from_the_sdram : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
                 signal zs_ba_from_the_sdram : BUFFER STD_LOGIC_VECTOR (1 DOWNTO 0);
                 signal zs_cas_n_from_the_sdram : OUT STD_LOGIC;
                 signal zs_cke_from_the_sdram : OUT STD_LOGIC;
                 signal zs_cs_n_from_the_sdram : OUT STD_LOGIC;
                 signal zs_dq_to_and_from_the_sdram : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0);
                 signal zs_dqm_from_the_sdram : BUFFER STD_LOGIC_VECTOR (1 DOWNTO 0);
                 signal zs_ras_n_from_the_sdram : OUT STD_LOGIC;
                 signal zs_we_n_from_the_sdram : OUT STD_LOGIC
              );
	end component;
	
	component sdram_pll
		port (
				 signal inclk0 : IN STD_LOGIC;
				 signal c0 : OUT STD_LOGIC;
				 signal c1 : OUT STD_LOGIC
			 );
	end component;

-------------------------------------------------------------------------------
--                           Parameter Declarations                          --
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--                 Internal Wires and Registers Declarations                 --
-------------------------------------------------------------------------------
-- Internal Wires
-- Used to connect the Nios 2 system clock to the non-shifted output of the PLL
signal			 system_clock : STD_LOGIC;

-- Used to concatenate some SDRAM control signals
signal			 BA : STD_LOGIC_VECTOR(1 DOWNTO 0);
signal			 DQM : STD_LOGIC_VECTOR(1 DOWNTO 0);

-- Internal Registers

-- State Machine Registers

begin

-------------------------------------------------------------------------------
--                         Finite State Machine(s)                           --
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--                             Sequential Logic                              --
-------------------------------------------------------------------------------
	
-------------------------------------------------------------------------------
--                            Combinational Logic                            --
-------------------------------------------------------------------------------

DRAM_BA_1  <= BA(1);
DRAM_BA_0  <= BA(0);
DRAM_UDQM  <= DQM(1);
DRAM_LDQM  <= DQM(0);

GPIO_0( 0) <= 'Z';
GPIO_0( 2) <= 'Z';
GPIO_0(16) <= 'Z';
GPIO_0(18) <= 'Z';
GPIO_1( 0) <= 'Z';
GPIO_1( 2) <= 'Z';
GPIO_1(16) <= 'Z';
GPIO_1(18) <= 'Z';

-------------------------------------------------------------------------------
--                              Internal Modules                             --
-------------------------------------------------------------------------------



NiosII : nios_system
	port map(
		-- 1) global signals:
		clk       								=> system_clock,
		reset_n    								=> KEY(0),
	
		-- the_Slider_switches
		SW_to_the_Slider_switches				=> SW,
		
		-- the_Pushbuttons
		KEY_to_the_Pushbuttons					=> (KEY(3 downto 1) & "1"),

		-- the_Expansion_JP1
		GPIO_0_to_and_from_the_Expansion_JP1(0)	=> GPIO_0(1),
		GPIO_0_to_and_from_the_Expansion_JP1(13 downto 1)	
												=> GPIO_0(15 downto 3),
		GPIO_0_to_and_from_the_Expansion_JP1(14)=> GPIO_0(17),
		GPIO_0_to_and_from_the_Expansion_JP1(31 downto 15)	
												=> GPIO_0(35 downto 19),

		-- the_Expansion_JP2
		GPIO_1_to_and_from_the_Expansion_JP2(0)	=> GPIO_1(1),
		GPIO_1_to_and_from_the_Expansion_JP2(13 downto 1)	
												=> GPIO_1(15 downto 3),
		GPIO_1_to_and_from_the_Expansion_JP2(14)=> GPIO_1(17),
		GPIO_1_to_and_from_the_Expansion_JP2(31 downto 15)	
												=> GPIO_1(35 downto 19),

		-- the_Green_LEDs
		LEDG_from_the_Green_LEDs 				=> LEDG,
		
		-- the_Red_LEDs
		LEDR_from_the_Red_LEDs 					=> LEDR,
		
		-- the_HEX3_HEX0
		HEX0_from_the_HEX3_HEX0 				=> HEX0,
		HEX1_from_the_HEX3_HEX0 				=> HEX1,
		HEX2_from_the_HEX3_HEX0 				=> HEX2,
		HEX3_from_the_HEX3_HEX0 				=> HEX3,
		
		-- the_SRAM
		SRAM_ADDR_from_the_SRAM					=> SRAM_ADDR,
		SRAM_CE_N_from_the_SRAM					=> SRAM_CE_N,
		SRAM_DQ_to_and_from_the_SRAM			=> SRAM_DQ,
		SRAM_LB_N_from_the_SRAM					=> SRAM_LB_N,
		SRAM_OE_N_from_the_SRAM					=> SRAM_OE_N,
		SRAM_UB_N_from_the_SRAM 				=> SRAM_UB_N,
		SRAM_WE_N_from_the_SRAM 				=> SRAM_WE_N,
		
		-- the_Serial_port
		UART_RXD_to_the_Serial_port				=> UART_RXD,
		UART_TXD_from_the_Serial_port			=> UART_TXD,
		
		-- the_sdram
		zs_addr_from_the_sdram					=> DRAM_ADDR,
		zs_ba_from_the_sdram					=> BA,
		zs_cas_n_from_the_sdram					=> DRAM_CAS_N,
		zs_cke_from_the_sdram					=> DRAM_CKE,
		zs_cs_n_from_the_sdram					=> DRAM_CS_N,
		zs_dq_to_and_from_the_sdram				=> DRAM_DQ,
		zs_dqm_from_the_sdram					=> DQM,
		zs_ras_n_from_the_sdram					=> DRAM_RAS_N,
		zs_we_n_from_the_sdram					=> DRAM_WE_N
	);
	
neg_3ns : sdram_pll
	port map (
		inclk0									=> CLOCK_50,
		c0										=> DRAM_CLK,
		c1										=> system_clock
	);

end DE1_Basic_Computer_rtl;

