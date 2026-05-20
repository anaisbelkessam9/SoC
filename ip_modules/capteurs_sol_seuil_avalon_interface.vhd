--------------------------------------------------------------------------------
-- Interface Avalon MM pour module capteurs de sol
-- Connexion du module capteurs_sol_seuil au bus Avalon Memory-Mapped
-- Registres 8 bits accessibles par le Nios II
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity capteurs_sol_seuil_avalon_interface is
    port (
        ------------------------------------------------------------------------
        -- Interface Avalon MM (horloge et reset)
        ------------------------------------------------------------------------
        clock  : in std_logic;  -- 50 MHz depuis Qsys
        resetn : in std_logic;  -- Reset actif bas

        ------------------------------------------------------------------------
        -- Bus Avalon Memory-Mapped Slave (8 bits)
        ------------------------------------------------------------------------
        address    : in  std_logic_vector(3 downto 0);   -- Adresse registre (4 bits)
        chipselect : in  std_logic;                      -- Sélection composant
        write      : in  std_logic;                      -- Signal écriture
        read       : in  std_logic;                      -- Signal lecture
        byteenable : in  std_logic_vector(0 downto 0);   -- Enable octet
        writedata  : in  std_logic_vector(7 downto 0);   -- Données à écrire
        readdata   : out std_logic_vector(7 downto 0);   -- Données lues

        ------------------------------------------------------------------------
        -- Conduit vers ADC externe LTC2308
        ------------------------------------------------------------------------
        ADC_SPI : out std_logic_vector(2 downto 0);  -- [CONVST, SCK, SDI]
        ADC_SDO : in  std_logic                      -- Données de l'ADC
    );
end entity capteurs_sol_seuil_avalon_interface;

architecture rtl of capteurs_sol_seuil_avalon_interface is

    ------------------------------------------------------------------------
    -- Carte mémoire des registres (offsets 8 bits)
    ------------------------------------------------------------------------
    constant ADDR_READY_VECT : std_logic_vector(3 downto 0) := "0000";  -- 0x00
    constant ADDR_NIVEAU     : std_logic_vector(3 downto 0) := "0001";  -- 0x01
    constant ADDR_DATA0      : std_logic_vector(3 downto 0) := "0010";  -- 0x02
    constant ADDR_DATA1      : std_logic_vector(3 downto 0) := "0011";  -- 0x03
    constant ADDR_DATA2      : std_logic_vector(3 downto 0) := "0100";  -- 0x04
    constant ADDR_DATA3      : std_logic_vector(3 downto 0) := "0101";  -- 0x05
    constant ADDR_DATA4      : std_logic_vector(3 downto 0) := "0110";  -- 0x06
    constant ADDR_DATA5      : std_logic_vector(3 downto 0) := "0111";  -- 0x07
    constant ADDR_DATA6      : std_logic_vector(3 downto 0) := "1000";  -- 0x08

    ------------------------------------------------------------------------
    -- Signaux PLL (génération 40 MHz et 2 kHz)
    ------------------------------------------------------------------------
    signal clk_40mhz_internal : std_logic;
    signal clk_2khz_trigger   : std_logic;
    signal pll_reset_signal   : std_logic;

    ------------------------------------------------------------------------
    -- Registre de seuillage (écrit par Nios)
    ------------------------------------------------------------------------
    signal niveau_reg : std_logic_vector(7 downto 0) := x"80";

    ------------------------------------------------------------------------
    -- Signaux en provenance du module capteurs_sol_seuil
    ------------------------------------------------------------------------
    signal sensor_data_ready : std_logic;
    
    signal sensor_data0 : std_logic_vector(7 downto 0);
    signal sensor_data1 : std_logic_vector(7 downto 0);
    signal sensor_data2 : std_logic_vector(7 downto 0);
    signal sensor_data3 : std_logic_vector(7 downto 0);
    signal sensor_data4 : std_logic_vector(7 downto 0);
    signal sensor_data5 : std_logic_vector(7 downto 0);
    signal sensor_data6 : std_logic_vector(7 downto 0);
    
    signal sensor_vect_capt : std_logic_vector(6 downto 0);

    ------------------------------------------------------------------------
    -- Registres snapshot (mémorisent les valeurs pour lecture Nios)
    ------------------------------------------------------------------------
    signal snapshot_data0 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data1 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data2 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data3 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data4 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data5 : std_logic_vector(7 downto 0) := (others => '0');
    signal snapshot_data6 : std_logic_vector(7 downto 0) := (others => '0');
    
    signal snapshot_vect : std_logic_vector(6 downto 0) := (others => '0');
    signal ready_flag    : std_logic := '0';

    ------------------------------------------------------------------------
    -- Synchroniseurs pour data_ready (traversée de domaine d'horloge)
    ------------------------------------------------------------------------
    signal ready_meta_ff : std_logic := '0';
    signal ready_sync_ff : std_logic := '0';
    signal ready_prev_ff : std_logic := '0';

    ------------------------------------------------------------------------
    -- Signaux SPI vers ADC
    ------------------------------------------------------------------------
    signal adc_convst_internal : std_logic;
    signal adc_sck_internal    : std_logic;
    signal adc_sdi_internal    : std_logic;

    ------------------------------------------------------------------------
    -- Déclaration composant PLL (génération 40 MHz et 2 kHz)
    ------------------------------------------------------------------------
    component pll_2freqs is
        port (
            areset : in  std_logic := '0';
            inclk0 : in  std_logic := '0';
            c0     : out std_logic;  -- 40 MHz
            c1     : out std_logic   -- 2 kHz
        );
    end component;

    ------------------------------------------------------------------------
    -- Déclaration module capteurs
    ------------------------------------------------------------------------
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

    ------------------------------------------------------------------------
    -- Instanciation PLL pour génération d'horloges
    ------------------------------------------------------------------------
    pll_reset_signal <= not resetn;

    pll_inst : pll_2freqs
        port map (
            areset => pll_reset_signal,
            inclk0 => clock,
            c0     => clk_40mhz_internal,  -- Horloge 40 MHz pour capteurs
            c1     => clk_2khz_trigger     -- Horloge 2 kHz pour trigger
        );

    ------------------------------------------------------------------------
    -- Mapping du conduit ADC (3 bits vers le top-level)
    ------------------------------------------------------------------------
    ADC_SPI(2) <= adc_convst_internal;  -- CONVST
    ADC_SPI(1) <= adc_sck_internal;     -- SCK
    ADC_SPI(0) <= adc_sdi_internal;     -- SDI

    ------------------------------------------------------------------------
    -- Instanciation du module capteurs
    ------------------------------------------------------------------------
    sensor_inst : capteurs_sol_seuil
        port map (
            clk          => clk_40mhz_internal,
            reset_n      => resetn,
            data_capture => clk_2khz_trigger,
            data_readyr  => sensor_data_ready,
            data0r       => sensor_data0,
            data1r       => sensor_data1,
            data2r       => sensor_data2,
            data3r       => sensor_data3,
            data4r       => sensor_data4,
            data5r       => sensor_data5,
            data6r       => sensor_data6,
            NIVEAU       => niveau_reg,
            vect_capt    => sensor_vect_capt,
            ADC_CONVSTr  => adc_convst_internal,
            ADC_SCK      => adc_sck_internal,
            ADC_SDIr     => adc_sdi_internal,
            ADC_SDO      => ADC_SDO
        );

    ------------------------------------------------------------------------
    -- PROCESS : Écriture Avalon + Snapshot des données capteurs
    ------------------------------------------------------------------------
    avalon_write_snapshot : process(clock, resetn)
    begin
        if resetn = '0' then
            -- Reset : valeur par défaut du seuil
            niveau_reg <= x"6C";
            
            -- Reset des snapshots
            snapshot_data0 <= (others => '0');
            snapshot_data1 <= (others => '0');
            snapshot_data2 <= (others => '0');
            snapshot_data3 <= (others => '0');
            snapshot_data4 <= (others => '0');
            snapshot_data5 <= (others => '0');
            snapshot_data6 <= (others => '0');
            snapshot_vect  <= (others => '0');
            ready_flag     <= '0';
            
            -- Reset synchroniseurs
            ready_meta_ff <= '0';
            ready_sync_ff <= '0';
            ready_prev_ff <= '0';
            
        elsif rising_edge(clock) then
            
            --------------------------------------------------------------------
            -- Écriture du registre NIVEAU par le Nios II
            --------------------------------------------------------------------
            if chipselect = '1' and write = '1' and byteenable(0) = '1' then
                if address = ADDR_NIVEAU then
                    niveau_reg <= writedata;
                end if;
            end if;
            
            --------------------------------------------------------------------
            -- Synchronisation de data_ready (traversée de domaine d'horloge)
            -- Double flip-flop pour éviter métastabilité
            --------------------------------------------------------------------
            ready_meta_ff <= sensor_data_ready;
            ready_sync_ff <= ready_meta_ff;
            ready_prev_ff <= ready_sync_ff;
            
            --------------------------------------------------------------------
            -- Détection front montant : mémorisation des données
            --------------------------------------------------------------------
            if ready_sync_ff = '1' and ready_prev_ff = '0' then
                snapshot_data0 <= sensor_data0;
                snapshot_data1 <= sensor_data1;
                snapshot_data2 <= sensor_data2;
                snapshot_data3 <= sensor_data3;
                snapshot_data4 <= sensor_data4;
                snapshot_data5 <= sensor_data5;
                snapshot_data6 <= sensor_data6;
                snapshot_vect  <= sensor_vect_capt;
                ready_flag     <= '1';
            end if;
            
        end if;
    end process avalon_write_snapshot;

    ------------------------------------------------------------------------
    -- PROCESS : Lecture des registres par Avalon
    ------------------------------------------------------------------------
    avalon_read : process(address, chipselect, read, ready_flag, niveau_reg,
                         snapshot_vect, snapshot_data0, snapshot_data1,
                         snapshot_data2, snapshot_data3, snapshot_data4,
                         snapshot_data5, snapshot_data6)
    begin
        readdata <= (others => '0');
        
        if chipselect = '1' and read = '1' then
            case address is
                
                ----------------------------------------------------------------
                -- 0x00 : READY_VECT
                -- bit 7    = ready_flag
                -- bits 6:0 = vect_capt seuillé
                ----------------------------------------------------------------
                when ADDR_READY_VECT =>
                    readdata <= ready_flag & snapshot_vect;
                
                ----------------------------------------------------------------
                -- 0x01 : NIVEAU (seuil de comparaison)
                ----------------------------------------------------------------
                when ADDR_NIVEAU =>
                    readdata <= niveau_reg;
                
                ----------------------------------------------------------------
                -- 0x02 à 0x08 : Données des 7 capteurs
                ----------------------------------------------------------------
                when ADDR_DATA0 =>
                    readdata <= snapshot_data0;
                
                when ADDR_DATA1 =>
                    readdata <= snapshot_data1;
                
                when ADDR_DATA2 =>
                    readdata <= snapshot_data2;
                
                when ADDR_DATA3 =>
                    readdata <= snapshot_data3;
                
                when ADDR_DATA4 =>
                    readdata <= snapshot_data4;
                
                when ADDR_DATA5 =>
                    readdata <= snapshot_data5;
                
                when ADDR_DATA6 =>
                    readdata <= snapshot_data6;
                
                when others =>
                    readdata <= (others => '0');
                    
            end case;
        end if;
    end process avalon_read;

end architecture rtl;