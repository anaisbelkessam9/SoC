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
    DRAM_DQ              : inout std_logic_vector (15 downto 0);

    -- Outputs
    LEDG                 : out std_logic_vector (7 downto 0);
    LEDR                 : out std_logic_vector (9 downto 0);
    HEX0                 : out std_logic_vector (6 downto 0);
    HEX1                 : out std_logic_vector (6 downto 0);
    HEX2                 : out std_logic_vector (6 downto 0);
    HEX3                 : out std_logic_vector (6 downto 0);

    -- Memory (SRAM)
    SRAM_ADDR            : out std_logic_vector (17 downto 0);
    SRAM_CE_N            : out std_logic;
    SRAM_WE_N            : out std_logic;
    SRAM_OE_N            : out std_logic;
    SRAM_UB_N            : out std_logic;
    SRAM_LB_N            : out std_logic;

    -- Communication
    UART_TXD             : out std_logic;

    -- Memory (SDRAM)
    DRAM_ADDR            : out std_logic_vector (11 downto 0);
    DRAM_BA_1            : buffer std_logic;
    DRAM_BA_0            : buffer std_logic;
    DRAM_CAS_N           : out std_logic;
    DRAM_RAS_N           : out std_logic;
    DRAM_CLK             : out std_logic;
    DRAM_CKE             : out std_logic;
    DRAM_CS_N            : out std_logic;
    DRAM_WE_N            : out std_logic;
    DRAM_UDQM            : buffer std_logic;
    DRAM_LDQM            : buffer std_logic
    );
end DE1_Basic_Computer;


architecture DE1_Basic_Computer_rtl of DE1_Basic_Computer is

-------------------------------------------------------------------------------
--                           Subentity Declarations                          --
-------------------------------------------------------------------------------

    component nios_system is
        port (
            SRAM_DQ_to_and_from_the_SRAM         : inout std_logic_vector(15 downto 0);
            SRAM_ADDR_from_the_SRAM              : out   std_logic_vector(17 downto 0);
            SRAM_LB_N_from_the_SRAM              : out   std_logic;
            SRAM_UB_N_from_the_SRAM              : out   std_logic;
            SRAM_CE_N_from_the_SRAM              : out   std_logic;
            SRAM_OE_N_from_the_SRAM              : out   std_logic;
            SRAM_WE_N_from_the_SRAM              : out   std_logic;
            reset_n                              : in    std_logic;
            GPIO_0_to_and_from_the_Expansion_JP1 : inout std_logic_vector(31 downto 0);
            LEDG_from_the_Green_LEDs             : out   std_logic_vector(7 downto 0);
            zs_addr_from_the_sdram               : out   std_logic_vector(11 downto 0);
            zs_ba_from_the_sdram                 : out   std_logic_vector(1 downto 0);
            zs_cas_n_from_the_sdram              : out   std_logic;
            zs_cke_from_the_sdram                : out   std_logic;
            zs_cs_n_from_the_sdram               : out   std_logic;
            zs_dq_to_and_from_the_sdram          : inout std_logic_vector(15 downto 0);
            zs_dqm_from_the_sdram                : out   std_logic_vector(1 downto 0);
            zs_ras_n_from_the_sdram              : out   std_logic;
            zs_we_n_from_the_sdram               : out   std_logic;
            GPIO_1_to_and_from_the_Expansion_JP2 : inout std_logic_vector(31 downto 0);
            UART_RXD_to_the_Serial_port          : in    std_logic;
            UART_TXD_from_the_Serial_port        : out   std_logic;
            clk                                  : in    std_logic;
            KEY_to_the_Pushbuttons               : in    std_logic_vector(3 downto 0);
            SW_to_the_Slider_switches            : in    std_logic_vector(9 downto 0);
            LEDR_from_the_Red_LEDs               : out   std_logic_vector(9 downto 0);
            HEX0_from_the_HEX3_HEX0              : out   std_logic_vector(6 downto 0);
            HEX1_from_the_HEX3_HEX0              : out   std_logic_vector(6 downto 0);
            HEX2_from_the_HEX3_HEX0              : out   std_logic_vector(6 downto 0);
            HEX3_from_the_HEX3_HEX0              : out   std_logic_vector(6 downto 0);
            to_hex_export                        : out   std_logic_vector(15 downto 0)
        );
    end component nios_system;

    component sdram_pll
        port (
            signal inclk0 : in  std_logic;
            signal c0     : out std_logic;
            signal c1     : out std_logic
        );
    end component;

    component hex7seg is
        port (
            hex     : in  std_logic_vector(3 downto 0);
            display : out std_logic_vector(0 to 6)
        );
    end component hex7seg;

-------------------------------------------------------------------------------
--                 Internal Wires and Registers Declarations                 --
-------------------------------------------------------------------------------

signal system_clock : std_logic;

signal BA  : std_logic_vector(1 downto 0);
signal DQM : std_logic_vector(1 downto 0);

signal to_HEX : std_logic_vector(15 downto 0);

signal HEX0_wire : std_logic_vector(0 to 6);
signal HEX1_wire : std_logic_vector(0 to 6);
signal HEX2_wire : std_logic_vector(0 to 6);
signal HEX3_wire : std_logic_vector(0 to 6);

begin

-------------------------------------------------------------------------------
--                            Combinational Logic                            --
-------------------------------------------------------------------------------

DRAM_BA_1 <= BA(1);
DRAM_BA_0 <= BA(0);
DRAM_UDQM <= DQM(1);
DRAM_LDQM <= DQM(0);

GPIO_0( 0) <= 'Z';
GPIO_0( 2) <= 'Z';
GPIO_0(16) <= 'Z';
GPIO_0(18) <= 'Z';
GPIO_1( 0) <= 'Z';
GPIO_1( 2) <= 'Z';
GPIO_1(16) <= 'Z';
GPIO_1(18) <= 'Z';

-- Adaptation because tutorial hex7seg uses std_logic_vector(0 to 6)
-- while this DE1 top uses std_logic_vector(6 downto 0)
HEX0 <= HEX0_wire(6) & HEX0_wire(5) & HEX0_wire(4) & HEX0_wire(3) & HEX0_wire(2) & HEX0_wire(1) & HEX0_wire(0);
HEX1 <= HEX1_wire(6) & HEX1_wire(5) & HEX1_wire(4) & HEX1_wire(3) & HEX1_wire(2) & HEX1_wire(1) & HEX1_wire(0);
HEX2 <= HEX2_wire(6) & HEX2_wire(5) & HEX2_wire(4) & HEX2_wire(3) & HEX2_wire(2) & HEX2_wire(1) & HEX2_wire(0);
HEX3 <= HEX3_wire(6) & HEX3_wire(5) & HEX3_wire(4) & HEX3_wire(3) & HEX3_wire(2) & HEX3_wire(1) & HEX3_wire(0);

-------------------------------------------------------------------------------
--                              Internal Modules                             --
-------------------------------------------------------------------------------

NiosII : nios_system
    port map (
        -- SRAM
        SRAM_DQ_to_and_from_the_SRAM         => SRAM_DQ,
        SRAM_ADDR_from_the_SRAM              => SRAM_ADDR,
        SRAM_LB_N_from_the_SRAM              => SRAM_LB_N,
        SRAM_UB_N_from_the_SRAM              => SRAM_UB_N,
        SRAM_CE_N_from_the_SRAM              => SRAM_CE_N,
        SRAM_OE_N_from_the_SRAM              => SRAM_OE_N,
        SRAM_WE_N_from_the_SRAM              => SRAM_WE_N,

        -- Reset
        reset_n                              => KEY(0),

        -- Expansion JP1
        GPIO_0_to_and_from_the_Expansion_JP1(0)              => GPIO_0(1),
        GPIO_0_to_and_from_the_Expansion_JP1(13 downto 1)    => GPIO_0(15 downto 3),
        GPIO_0_to_and_from_the_Expansion_JP1(14)             => GPIO_0(17),
        GPIO_0_to_and_from_the_Expansion_JP1(31 downto 15)   => GPIO_0(35 downto 19),

        -- Green LEDs
        LEDG_from_the_Green_LEDs             => LEDG,

        -- SDRAM
        zs_addr_from_the_sdram               => DRAM_ADDR,
        zs_ba_from_the_sdram                 => BA,
        zs_cas_n_from_the_sdram              => DRAM_CAS_N,
        zs_cke_from_the_sdram                => DRAM_CKE,
        zs_cs_n_from_the_sdram               => DRAM_CS_N,
        zs_dq_to_and_from_the_sdram          => DRAM_DQ,
        zs_dqm_from_the_sdram                => DQM,
        zs_ras_n_from_the_sdram              => DRAM_RAS_N,
        zs_we_n_from_the_sdram               => DRAM_WE_N,

        -- Expansion JP2
        GPIO_1_to_and_from_the_Expansion_JP2(0)              => GPIO_1(1),
        GPIO_1_to_and_from_the_Expansion_JP2(13 downto 1)    => GPIO_1(15 downto 3),
        GPIO_1_to_and_from_the_Expansion_JP2(14)             => GPIO_1(17),
        GPIO_1_to_and_from_the_Expansion_JP2(31 downto 15)   => GPIO_1(35 downto 19),

        -- Serial port
        UART_RXD_to_the_Serial_port          => UART_RXD,
        UART_TXD_from_the_Serial_port        => UART_TXD,

        -- Clock
        clk                                  => system_clock,

        -- Pushbuttons and switches
        KEY_to_the_Pushbuttons               => KEY(3 downto 1) & '1',
        SW_to_the_Slider_switches            => SW,

        -- Red LEDs
        LEDR_from_the_Red_LEDs               => LEDR,

        -- Original Qsys HEX outputs disconnected.
        -- Physical HEX displays are now driven by hex7seg below.
        HEX0_from_the_HEX3_HEX0              => open,
        HEX1_from_the_HEX3_HEX0              => open,
        HEX2_from_the_HEX3_HEX0              => open,
        HEX3_from_the_HEX3_HEX0              => open,

        -- Custom conduit from reg16 component
        to_hex_export                        => to_HEX
    );

h0 : hex7seg
    port map (
        hex     => to_HEX(3 downto 0),
        display => HEX0_wire
    );

h1 : hex7seg
    port map (
        hex     => to_HEX(7 downto 4),
        display => HEX1_wire
    );

h2 : hex7seg
    port map (
        hex     => to_HEX(11 downto 8),
        display => HEX2_wire
    );

h3 : hex7seg
    port map (
        hex     => to_HEX(15 downto 12),
        display => HEX3_wire
    );

neg_3ns : sdram_pll
    port map (
        inclk0 => CLOCK_50,
        c0     => DRAM_CLK,
        c1     => system_clock
    );

end DE1_Basic_Computer_rtl;