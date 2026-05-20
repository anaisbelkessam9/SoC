library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity capteurs_sol_seuil_avalon_interface is
    port (
        ----------------------------------------------------------------
        -- Avalon clock and reset
        ----------------------------------------------------------------
        clock  : in std_logic;   -- 50 MHz Qsys
        resetn : in std_logic;

        ----------------------------------------------------------------
        -- Avalon-MM slave 8 bits
        ----------------------------------------------------------------
        address    : in  std_logic_vector(3 downto 0);
        chipselect : in  std_logic;
        write      : in  std_logic;
        read       : in  std_logic;
        byteenable : in  std_logic_vector(0 downto 0);
        writedata  : in  std_logic_vector(7 downto 0);
        readdata   : out std_logic_vector(7 downto 0);

        ----------------------------------------------------------------
        -- Conduit ADC LTC2308
        ----------------------------------------------------------------
        ADC_SPI : out std_logic_vector(2 downto 0);
        ADC_SDO : in  std_logic
    );
end entity capteurs_sol_seuil_avalon_interface;


architecture rtl of capteurs_sol_seuil_avalon_interface is

    --------------------------------------------------------------------
    -- Register map 8 bits
    --------------------------------------------------------------------
    constant REG_READY_VECT : std_logic_vector(3 downto 0) := "0000"; -- 0x00
    constant REG_NIVEAU     : std_logic_vector(3 downto 0) := "0001"; -- 0x01
    constant REG_DATA0      : std_logic_vector(3 downto 0) := "0010"; -- 0x02
    constant REG_DATA1      : std_logic_vector(3 downto 0) := "0011"; -- 0x03
    constant REG_DATA2      : std_logic_vector(3 downto 0) := "0100"; -- 0x04
    constant REG_DATA3      : std_logic_vector(3 downto 0) := "0101"; -- 0x05
    constant REG_DATA4      : std_logic_vector(3 downto 0) := "0110"; -- 0x06
    constant REG_DATA5      : std_logic_vector(3 downto 0) := "0111"; -- 0x07
    constant REG_DATA6      : std_logic_vector(3 downto 0) := "1000"; -- 0x08

    --------------------------------------------------------------------
    -- PLL signals
    --------------------------------------------------------------------
    signal clk_40mhz : std_logic;
    signal clk_2khz  : std_logic;
    signal pll_reset : std_logic;

    --------------------------------------------------------------------
    -- Register written by Nios
    --------------------------------------------------------------------
    signal niveau_reg : std_logic_vector(7 downto 0) := x"80";

    --------------------------------------------------------------------
    -- Signals from capteurs_sol_seuil
    --------------------------------------------------------------------
    signal data_ready_s : std_logic;

    signal data0_s : std_logic_vector(7 downto 0);
    signal data1_s : std_logic_vector(7 downto 0);
    signal data2_s : std_logic_vector(7 downto 0);
    signal data3_s : std_logic_vector(7 downto 0);
    signal data4_s : std_logic_vector(7 downto 0);
    signal data5_s : std_logic_vector(7 downto 0);
    signal data6_s : std_logic_vector(7 downto 0);

    signal vect_capt_s : std_logic_vector(6 downto 0);

    --------------------------------------------------------------------
    -- Snapshot registers read by Nios
    --------------------------------------------------------------------
    signal snap_data0 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data1 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data2 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data3 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data4 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data5 : std_logic_vector(7 downto 0) := (others => '0');
    signal snap_data6 : std_logic_vector(7 downto 0) := (others => '0');

    signal snap_vect  : std_logic_vector(6 downto 0) := (others => '0');
    signal ready_reg  : std_logic := '0';

    --------------------------------------------------------------------
    -- Synchronisation data_ready vers clock Avalon
    --------------------------------------------------------------------
    signal ready_meta : std_logic := '0';
    signal ready_sync : std_logic := '0';
    signal ready_old  : std_logic := '0';

    --------------------------------------------------------------------
    -- ADC signals
    --------------------------------------------------------------------
    signal adc_convst_s : std_logic;
    signal adc_sck_s    : std_logic;
    signal adc_sdi_s    : std_logic;

    --------------------------------------------------------------------
    -- PLL component
    --------------------------------------------------------------------
    component pll_2freqs is
        port (
            areset : in  std_logic := '0';
            inclk0 : in  std_logic := '0';
            c0     : out std_logic;
            c1     : out std_logic
        );
    end component;

    --------------------------------------------------------------------
    -- Sensor component
    --------------------------------------------------------------------
    component capteurs_sol_seuil is
        port (
            clk          : in  std_logic;
            reset_n      : in  std_logic;

            data_capture : in  std_logic;
            data_readyr  : out std_logic;

            data0r       : out std_logic_vector(7 downto 0);
            data1r       : out std_logic_vector(7 downto 0);
            data2r       : out std_logic_vector(7 downto 0);
            data3r       : out std_logic_vector(7 downto 0);
            data4r       : out std_logic_vector(7 downto 0);
            data5r       : out std_logic_vector(7 downto 0);
            data6r       : out std_logic_vector(7 downto 0);

            NIVEAU       : in  std_logic_vector(7 downto 0);
            vect_capt    : out std_logic_vector(6 downto 0);

            ADC_CONVSTr  : out std_logic;
            ADC_SCK      : out std_logic;
            ADC_SDIr     : out std_logic;
            ADC_SDO      : in  std_logic
        );
    end component;

begin

    --------------------------------------------------------------------
    -- PLL
    --------------------------------------------------------------------
    pll_reset <= not resetn;

    u_pll : pll_2freqs
        port map (
            areset => pll_reset,
            inclk0 => clock,
            c0     => clk_40mhz, -- 40 MHz pour capteurs_sol_seuil
            c1     => clk_2khz   -- 2 kHz pour data_capture
        );

    --------------------------------------------------------------------
    -- ADC conduit mapping
    --------------------------------------------------------------------
    -- ADC_SPI(2) = ADC_CONVST
    -- ADC_SPI(1) = ADC_SCK
    -- ADC_SPI(0) = ADC_SDI
    --------------------------------------------------------------------
    ADC_SPI(2) <= adc_convst_s;
    ADC_SPI(1) <= adc_sck_s;
    ADC_SPI(0) <= adc_sdi_s;

    --------------------------------------------------------------------
    -- Sensor block
    --------------------------------------------------------------------
    u_capteurs : capteurs_sol_seuil
        port map (
            clk          => clk_40mhz,
            reset_n      => resetn,

            -- data_capture piloté par la PLL 2 kHz
            data_capture => clk_2khz,
            data_readyr  => data_ready_s,

            data0r       => data0_s,
            data1r       => data1_s,
            data2r       => data2_s,
            data3r       => data3_s,
            data4r       => data4_s,
            data5r       => data5_s,
            data6r       => data6_s,

            NIVEAU       => niveau_reg,
            vect_capt    => vect_capt_s,

            ADC_CONVSTr  => adc_convst_s,
            ADC_SCK      => adc_sck_s,
            ADC_SDIr     => adc_sdi_s,
            ADC_SDO      => ADC_SDO
        );

    --------------------------------------------------------------------
    -- PROCESS 1: écriture Nios + snapshot capteurs
    --------------------------------------------------------------------
    p_write_snapshot : process(clock, resetn)
    begin
        if resetn = '0' then

            niveau_reg <= x"6C";

            snap_data0 <= (others => '0');
            snap_data1 <= (others => '0');
            snap_data2 <= (others => '0');
            snap_data3 <= (others => '0');
            snap_data4 <= (others => '0');
            snap_data5 <= (others => '0');
            snap_data6 <= (others => '0');

            snap_vect  <= (others => '0');
            ready_reg  <= '0';

            ready_meta <= '0';
            ready_sync <= '0';
            ready_old  <= '0';

        elsif rising_edge(clock) then

            ------------------------------------------------------------
            -- Écriture du seuil NIVEAU par le Nios
            -- Offset 0x01
            ------------------------------------------------------------
            if chipselect = '1' and write = '1' and byteenable(0) = '1' then
                if address = REG_NIVEAU then
                    niveau_reg <= writedata;
                end if;
            end if;

            ------------------------------------------------------------
            -- Synchronisation de data_readyr vers clock Avalon
            ------------------------------------------------------------
            ready_meta <= data_ready_s;
            ready_sync <= ready_meta;
            ready_old  <= ready_sync;

            ------------------------------------------------------------
            -- Sur front montant de ready_sync :
            -- on mémorise les 7 capteurs et vect_capt
            ------------------------------------------------------------
            if ready_sync = '1' and ready_old = '0' then

                snap_data0 <= data0_s;
                snap_data1 <= data1_s;
                snap_data2 <= data2_s;
                snap_data3 <= data3_s;
                snap_data4 <= data4_s;
                snap_data5 <= data5_s;
                snap_data6 <= data6_s;

                snap_vect  <= vect_capt_s;
                ready_reg  <= '1';

            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- PROCESS 2: lecture Avalon
    --------------------------------------------------------------------
    p_read : process(address, chipselect, read,
                     ready_reg, niveau_reg, snap_vect,
                     snap_data0, snap_data1, snap_data2, snap_data3,
                     snap_data4, snap_data5, snap_data6)
    begin

        readdata <= (others => '0');

        if chipselect = '1' and read = '1' then

            case address is

                --------------------------------------------------------
                -- 0x00 : READY_VECT
                -- bit 7    = ready
                -- bits 6:0 = vect_capt
                --------------------------------------------------------
                when REG_READY_VECT =>
                    readdata <= ready_reg & snap_vect;

                --------------------------------------------------------
                -- 0x01 : NIVEAU
                --------------------------------------------------------
                when REG_NIVEAU =>
                    readdata <= niveau_reg;

                --------------------------------------------------------
                -- 0x02 à 0x08 : DATA0 à DATA6
                --------------------------------------------------------
                when REG_DATA0 =>
                    readdata <= snap_data0;

                when REG_DATA1 =>
                    readdata <= snap_data1;

                when REG_DATA2 =>
                    readdata <= snap_data2;

                when REG_DATA3 =>
                    readdata <= snap_data3;

                when REG_DATA4 =>
                    readdata <= snap_data4;

                when REG_DATA5 =>
                    readdata <= snap_data5;

                when REG_DATA6 =>
                    readdata <= snap_data6;

                when others =>
                    readdata <= (others => '0');

            end case;

        end if;

    end process;

end architecture rtl;