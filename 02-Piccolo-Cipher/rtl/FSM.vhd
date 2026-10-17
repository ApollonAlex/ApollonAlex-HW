library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FSM is
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;

    start    : in  std_logic;

    -- 0: 80-bit mode (25 rounds), 1: 128-bit mode (31 rounds)
    key_mode : in  std_logic;

    -- Serial inputs (16-bit chunks)
    key_in16  : in  std_logic_vector(15 downto 0);
    data_in16 : in  std_logic_vector(15 downto 0);

    -- Parallel outputs after LOADING
    key80_out   : out std_logic_vector(79 downto 0);
    key128_out  : out std_logic_vector(127 downto 0);
    data64_out  : out std_logic_vector(63 downto 0);

    -- FSM status
    loading_done : out std_logic := '0';
    encrypt_en   : out std_logic;
    done         : out std_logic;

    -- Round counter
    r_count      : out unsigned(4 downto 0);

    -- For key_scheduler_80
    i_mod5       : out std_logic_vector(2 downto 0);
    con_even     : out std_logic_vector(15 downto 0);
    con_odd      : out std_logic_vector(15 downto 0);

    -- For key_scheduler_128
    ip2_mod8     : out std_logic_vector(2 downto 0);
    ip3_mod8     : out std_logic_vector(2 downto 0);
    con_i        : out std_logic_vector(15 downto 0);
    con_ip1      : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of FSM is

  type state_t is (IDLE, LOADING, ENCRYPT, FINISH);
  signal state : state_t := IDLE;

  -- LOADING counter: 0..7 (8 cycles)
  signal load_cnt : unsigned(3 downto 0) := (others => '0');

  -- ENCRYPT round counter i: 0..24 or 0..30
  signal r_cnt    : unsigned(4 downto 0) := (others => '0');

  -- Internal shift registers
  signal key128_reg : std_logic_vector(127 downto 0) := (others => '0');
  signal key80_reg  : std_logic_vector(79 downto 0)  := (others => '0');
  signal data64_reg : std_logic_vector(63 downto 0)  := (others => '0');

begin

  ------------------------------------------------------------------------------
  -- Parallel outputs of loaded data
  ------------------------------------------------------------------------------
  key80_out  <= key80_reg;
  key128_out <= key128_reg;
  data64_out <= data64_reg;
  r_count    <= r_cnt;
  ------------------------------------------------------------------------------
  -- Status outputs
  ------------------------------------------------------------------------------
  
  --loading_done <= '1' when (state = ENCRYPT ) else '0';
  
  encrypt_en   <= '1' when (state = ENCRYPT) else '0';
  done         <= '1' when (state = FINISH) else '0';

  
  -- MAIN FSM (clocked)
  ------------------------------------------------------------------------------
  process(clk)
    variable rounds_max : unsigned(4 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state      <= IDLE;
        load_cnt   <= (others => '0');
        r_cnt      <= (others => '0');

        key128_reg <= (others => '0');
        key80_reg  <= (others => '0');
        data64_reg <= (others => '0');

      else
        case state is

          when IDLE =>
            load_cnt <= (others => '0');
            r_cnt    <= (others => '0');

            if start = '1' then
              key128_reg <= (others => '0');
              key80_reg  <= (others => '0');
              data64_reg <= (others => '0');
              state      <= LOADING;
            end if;

          when LOADING =>
            -- Always load 128-bit key (8 chunks)
            key128_reg <= key128_reg(111 downto 0) & key_in16;

            -- Load 80-bit key only for first 5 chunks (load_cnt=0..4)
            if load_cnt < "0110" then
              key80_reg <= key80_reg(63 downto 0) & key_in16;
            end if;

            -- Load data 64-bit only for first 4 chunks (load_cnt=0..3)
            if load_cnt <= "0100" then
              data64_reg <= data64_reg(47 downto 0) & data_in16;
            end if;

            if key_mode = '0' then 
                if load_cnt = "0110" then 
                   loading_done <= '1';
                else 
                   loading_done <= '0';
                end if;
            end if;
            
            if key_mode ='1' then 
               if load_cnt = "0111" then
                  loading_done <= '1';      
               else 
                  loading_done <='0';
               end if;
            end if; 

            -- advance loading counter
            if load_cnt = "1000" then
              load_cnt <= (others => '0');
              r_cnt    <= (others => '0');
              state    <= ENCRYPT;
              
            else
              load_cnt <= load_cnt + 1;
             end if;

          when ENCRYPT =>
            -- decide max rounds based on key_mode
            if key_mode = '0' then
              rounds_max := to_unsigned(24, 5); -- 25 rounds: i=0..24
            else
              rounds_max := to_unsigned(30, 5); -- 31 rounds: i=0..30
            end if;

            if r_cnt = rounds_max then
              state <= FINISH;
            else
              r_cnt <= r_cnt + 1;
            end if;

          when FINISH =>
            if start = '0' then
              state <= IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- i_mod5, ip2_mod8, ip3_mod8 (combinational from r_cnt)
  ------------------------------------------------------------------------------
-- process(clk)
--  variable c0: std_logic_vector(4 downto 0);
--  variable c1: std_logic_vector(4 downto 0);
--  variable con_v : std_logic_vector(31 downto 0);
--  variable base_v : std_logic_vector(31 downto 0);
-- begin
--    c1:= "00001";
--    c0:= "00000";
--    if rising_edge(clk) then
--        if r_cnt = 0 then
--            i_mod5 <= std_logic_vector(resize(r_cnt mod 5, 3));
--            base_v := c1 & c0 & c1 & "00" & c1 & c0 & c1;
--            ip2_mod8 <= std_logic_vector(resize((r_cnt +2) mod 8, 3)); 
--            ip3_mod8 <= std_logic_vector(resize((r_cnt +3) mod 8, 3));
--        if key_mode = '0' then
--              con_v := base_v xor x"0F1E2D3C";
--        else
--              con_v := base_v xor x"6547A98B";
--        end if;
--
--              con_even <= con_v(31 downto 16);
--              con_odd  <= con_v(15 downto 0);

              --con_i    <= con_v(31 downto 16);
--              con_ip1  <= con_v(15 downto 0);
--        end if;
--     end if;
-- end process;
  
  process(r_cnt)
    variable i_int : integer;
    variable m5    : integer;
    variable ip2   : integer;
    variable ip3   : integer;
  begin
    i_int := to_integer(r_cnt);

    m5 := i_int mod 5;
    i_mod5 <= std_logic_vector(to_unsigned(m5, 3));

    ip2 := (i_int + 2) mod 8;
    ip3 := (i_int + 3) mod 8;

    ip2_mod8 <= std_logic_vector(to_unsigned(ip2, 3));
    ip3_mod8 <= std_logic_vector(to_unsigned(ip3, 3));
  end process;

  ------------------------------------------------------------------------------
  -- Constant generation
  ------------------------------------------------------------------------------
  process(r_cnt, key_mode)
    variable i_int   : integer;
    variable c0      : std_logic_vector(4 downto 0);
    variable cip1    : std_logic_vector(4 downto 0);
    variable base_v  : std_logic_vector(31 downto 0);
    variable con_v   : std_logic_vector(31 downto 0);
  begin
    i_int := to_integer(r_cnt);

    c0   := "00000";
    cip1 := std_logic_vector(to_unsigned(i_int + 1, 5));

    base_v := cip1 & c0 & cip1 & "00" & cip1 & c0 & cip1;

    if key_mode = '0' then
      con_v := base_v xor x"0F1E2D3C";
    else
      con_v := base_v xor x"6547A98B";
    end if;

    con_even <= con_v(31 downto 16);
    con_odd  <= con_v(15 downto 0);

    con_i    <= con_v(31 downto 16);
    con_ip1  <= con_v(15 downto 0);
  end process;

end architecture;

